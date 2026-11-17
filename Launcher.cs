using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace NotchXLauncher
{
    class Program
    {
        private static HttpListener _listener;
        private static string _webRoot;
        private static bool _running = true;

        static void Main(string[] args)
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            if (Directory.Exists(Path.Combine(baseDir, "web")))
            {
                _webRoot = Path.Combine(baseDir, "web");
            }
            else if (Directory.Exists(Path.Combine(baseDir, "build", "web")))
            {
                _webRoot = Path.Combine(baseDir, "build", "web");
            }
            else
            {
                _webRoot = baseDir;
            }

            int port = GetFreePort();
            string url = "http://127.0.0.1:" + port + "/";

            _listener = new HttpListener();
            _listener.Prefixes.Add(url);
            try
            {
                _listener.Start();
            }
            catch (Exception ex)
            {
                // Fallback to opening file directly or standard browser
                Process.Start(new ProcessStartInfo
                {
                    FileName = "http://127.0.0.1:" + port + "/",
                    UseShellExecute = true
                });
                return;
            }

            Task.Run(() => ServerLoop());

            string browserPath = FindBrowser();
            string profileDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "NotchX",
                "app_profile"
            );

            try
            {
                Directory.CreateDirectory(profileDir);
            }
            catch { }

            Process browserProcess = null;
            if (!string.IsNullOrEmpty(browserPath))
            {
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = browserPath,
                    Arguments = string.Format(
                        "--app=\"{0}\" --window-size=920,540 --user-data-dir=\"{1}\" --no-first-run --no-default-browser-check",
                        url,
                        profileDir
                    ),
                    UseShellExecute = false
                };
                browserProcess = Process.Start(psi);
            }
            else
            {
                browserProcess = Process.Start(new ProcessStartInfo
                {
                    FileName = url,
                    UseShellExecute = true
                });
            }

            if (browserProcess != null)
            {
                browserProcess.WaitForExit();
            }

            _running = false;
            try { _listener.Stop(); } catch { }
        }

        private static int GetFreePort()
        {
            TcpListener l = new TcpListener(IPAddress.Loopback, 0);
            l.Start();
            int port = ((IPEndPoint)l.LocalEndpoint).Port;
            l.Stop();
            return port;
        }

        private static string FindBrowser()
        {
            string[] candidates = new string[]
            {
                @"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
                @"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
                @"C:\Program Files\Google\Chrome\Application\chrome.exe",
                @"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Microsoft\Edge\Application\msedge.exe")
            };

            foreach (string path in candidates)
            {
                if (File.Exists(path)) return path;
            }
            return null;
        }

        private static void ServerLoop()
        {
            while (_running && _listener.IsListening)
            {
                try
                {
                    HttpListenerContext context = _listener.GetContext();
                    Task.Run(() => HandleRequest(context));
                }
                catch
                {
                    if (!_running) break;
                }
            }
        }

        private static void HandleRequest(HttpListenerContext context)
        {
            try
            {
                string rawUrl = context.Request.Url.AbsolutePath;
                if (rawUrl == "/" || string.IsNullOrEmpty(rawUrl))
                {
                    rawUrl = "/index.html";
                }

                string filePath = Path.Combine(_webRoot, rawUrl.TrimStart('/').Replace('/', Path.DirectorySeparatorChar));

                if (File.Exists(filePath))
                {
                    byte[] data = File.ReadAllBytes(filePath);
                    context.Response.ContentType = GetMimeType(filePath);
                    context.Response.ContentLength64 = data.Length;
                    context.Response.AddHeader("Access-Control-Allow-Origin", "*");
                    context.Response.AddHeader("Cache-Control", "no-cache");
                    context.Response.OutputStream.Write(data, 0, data.Length);
                }
                else
                {
                    // Fallback to index.html for SPA routing
                    string indexPath = Path.Combine(_webRoot, "index.html");
                    if (File.Exists(indexPath))
                    {
                        byte[] data = File.ReadAllBytes(indexPath);
                        context.Response.ContentType = "text/html";
                        context.Response.ContentLength64 = data.Length;
                        context.Response.OutputStream.Write(data, 0, data.Length);
                    }
                    else
                    {
                        context.Response.StatusCode = 404;
                    }
                }
            }
            catch
            {
                try { context.Response.StatusCode = 500; } catch { }
            }
            finally
            {
                try { context.Response.Close(); } catch { }
            }
        }

        private static string GetMimeType(string path)
        {
            string ext = Path.GetExtension(path).ToLowerInvariant();
            switch (ext)
            {
                case ".html": return "text/html; charset=utf-8";
                case ".js": return "application/javascript; charset=utf-8";
                case ".json": return "application/json; charset=utf-8";
                case ".css": return "text/css; charset=utf-8";
                case ".png": return "image/png";
                case ".jpg":
                case ".jpeg": return "image/jpeg";
                case ".svg": return "image/svg+xml";
                case ".ico": return "image/x-icon";
                case ".wasm": return "application/wasm";
                case ".otf": return "font/otf";
                case ".ttf": return "font/ttf";
                case ".woff": return "font/woff";
                case ".woff2": return "font/woff2";
                default: return "application/octet-stream";
            }
        }
    }
}
