// TODO: si renombraste el paquete, cambia "verilang" por el nombre de tu lenguaje
package verilang.service

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import verilang.model.RunResult
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * servicio que invoca rascal como subproceso y devuelve el resultado parseado
 *
 * la estructura esperada del proyecto:
 *
 *   tu-proyecto/
 *   ├── rascal-shell-stable.jar   #el jar de Rascal
 *   ├── src/                      #tu código Rascal (módulos .rsc)
 *   │   └── verilang/
 *   │       └── RunnerJson.rsc    #punto de entrada Rascal
 *   └── kotlin-app/               #esta app
 *       └── ...
 *
 * el servicio sube un nivel desde kotlin-app/ para encontrar el jar y src/.
 */
class LangService {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    // sube un nivel desde kotlin-app/ para llegar a la raíz del proyecto
    private val projectRoot: File by lazy {
        val cwd = File(System.getProperty("user.dir"))
        val candidate = cwd.resolve("../rascal-shell-stable.jar")
        if (candidate.exists()) cwd.resolve("..").canonicalFile
        else {
            val alt = cwd.parentFile
            if (alt?.resolve("rascal-shell-stable.jar")?.exists() == true) alt
            else cwd.resolve("..").canonicalFile
        }
    }

    private val rascalJar: File get() = projectRoot.resolve("rascal-shell-stable.jar")
    private val srcDir: File get() = projectRoot
    
    //recibe la ruta absoluta del archivo fuente y devuelve el RunResult
    //se ejecuta en un hilo de I/O para no bloquear la interfaz
     
    suspend fun run(filePath: String): RunResult = withContext(Dispatchers.IO) {
        try {
            println("[LangService] Ejecutando Rascal...")
            println("[LangService] archivo : $filePath")
            println("[LangService] jar     : ${rascalJar.absolutePath}")
            println("[LangService] src     : ${srcDir.absolutePath}")

            val t0 = System.currentTimeMillis()
            val output = executeRascal(filePath)
            println("[LangService] tiempo  : ${System.currentTimeMillis() - t0} ms")
            println("[LangService] stdout  : ${output.length} chars")

            val jsonStr = extractJson(output)
            if (jsonStr == null) {
                println("[LangService] ERROR: no se encontró JSON en la salida de Rascal")
                return@withContext RunResult(error = "Rascal no produjo JSON válido:\n$output")
            }

            json.decodeFromString<RunResult>(jsonStr)
        } catch (e: Exception) {
            println("[LangService] excepción: ${e.message}")
            e.printStackTrace()
            RunResult(error = e.message ?: "Error desconocido")
        }
    }

    private fun executeRascal(filePath: String): String {
        if (!rascalJar.exists())
            throw RuntimeException("No se encontró rascal-shell-stable.jar en ${rascalJar.absolutePath}")
        if (!projectRoot.resolve("src/main/rascal").exists())
            throw RuntimeException("No se encontró el directorio src/main/rascal en ${projectRoot.resolve("src/main/rascal").absolutePath}")
        
        val inputFile = File(filePath).absolutePath.replace(File.separatorChar, '/')
        val rascalSource = projectRoot.resolve("src/main/rascal").absolutePath

        val cmd = listOf(
            "java",
            "-Dfile.encoding=UTF-8",
            "-Drascal.projectPath=${projectRoot.absolutePath}",
            "-Drascal.path=$rascalSource",
            "-jar", rascalJar.absolutePath,
            "RunnerJson",
            inputFile
        )

        val process = ProcessBuilder(cmd)
            .directory(srcDir)
            .redirectErrorStream(false)
            .start()
        process.outputStream.close()

        // leemos stdout y stderr en hilos separados para evitar deadlocks
        val stdoutFuture = java.util.concurrent.Executors.newSingleThreadExecutor()
            .submit<String> { process.inputStream.bufferedReader().readText() }
        val stderrFuture = java.util.concurrent.Executors.newSingleThreadExecutor()
            .submit<String> { process.errorStream.bufferedReader().readText() }

        val finished = process.waitFor(180, TimeUnit.SECONDS)
        if (!finished) {
            process.destroyForcibly()
            throw RuntimeException("Rascal tardó más de 180s y fue detenido")
        }

        val stdout = stdoutFuture.get()
        val stderr = stderrFuture.get()

        println("--- STDERR (${stderr.length} chars) ---")
        if (stderr.isNotBlank()) println(stderr)
        println("--- exit code: ${process.exitValue()} ---")

        if (process.exitValue() != 0 && stdout.isBlank())
            throw RuntimeException("Error de Rascal (exit ${process.exitValue()}):\n$stderr")

        return stdout
    }

    
    //Extrae el primer objeto JSON válido que contenga la clave "success"
    //de la salida de Rascal 
     
    private fun extractJson(output: String): String? {
        // elimina códigos de color ANSI que rascasl a veces imprime
        val clean = output
            .replace(Regex("\\x1b\\[[^a-zA-Z]*[a-zA-Z]"), "")
            .replace(Regex("\\x1b[^\\[\\x1b]"), "")

        var start = 0
        while (start < clean.length) {
            val brace = clean.indexOf('{', start)
            if (brace == -1) break
            var depth = 0; var inStr = false; var esc = false; var end = -1
            for (i in brace until clean.length) {
                val c = clean[i]
                if (esc)              { esc = false; continue }
                if (c == '\\' && inStr) { esc = true; continue }
                if (c == '"')         { inStr = !inStr; continue }
                if (!inStr) {
                    if (c == '{') depth++
                    else if (c == '}') { depth--; if (depth == 0) { end = i; break } }
                }
            }
            if (end != -1) {
                val candidate = clean.substring(brace, end + 1)
                try {
                    val parsed = Json.parseToJsonElement(candidate)
                    // Buscamos el JSON que tenga "success", el que produjo RunnerJson.rsc
                    if (parsed is kotlinx.serialization.json.JsonObject && parsed.containsKey("success"))
                        return candidate
                } catch (_: Exception) {}
            }
            start = brace + 1
        }
        return null
    }
}
