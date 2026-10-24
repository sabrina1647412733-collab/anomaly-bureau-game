// The outer process must choose TEMP before Inno's SetupLdr initializes.
// Child-only environment changes; never edits the registry or system settings.
using System;
using System.IO;
using System.Text;
using System.Diagnostics;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Security.Cryptography;
using System.Windows.Forms;
using System.Reflection;
[assembly: AssemblyTitle("诡异事务局安装入口")]
[assembly: AssemblyDescription("为安装和卸载选择可写的临时目录")]
class TempHost {
    static readonly byte[] Magic = Encoding.ASCII.GetBytes("ABSETUPPAYLOAD1!");
    static string Quote(string value) {
        var s = new StringBuilder("\""); int n = 0;
        foreach(char c in value) {
            if(c == '\\') { n++; continue; }
            s.Append('\\', c == '"' ? n * 2 + 1 : n); s.Append(c); n = 0;
        }
        return s.Append('\\', n * 2).Append('"').ToString();
    }
    static string Session(string self) {
        string[] roots = { @"F:\AnomalyBureau-SetupCache", Path.Combine(Path.GetDirectoryName(self), ".AnomalyBureau-SetupCache"), Path.Combine(Path.GetTempPath(), "AnomalyBureau-SetupCache") };
        Exception last = null;
        foreach(string root in roots) {
            string leaf = Path.Combine(root, Guid.NewGuid().ToString("N"));
            try {
                Directory.CreateDirectory(root);
                var acl = new DirectorySecurity();
                acl.SetAccessRuleProtection(true, false);
                acl.AddAccessRule(new FileSystemAccessRule(WindowsIdentity.GetCurrent().User, FileSystemRights.FullControl, InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit, PropagationFlags.None, AccessControlType.Allow));
                Directory.CreateDirectory(leaf, acl);
                string probe = Path.Combine(leaf, "write-probe");
                File.WriteAllText(probe, "ok"); File.Delete(probe);
                return leaf;
            } catch(Exception e) { last = e; }
        }
        throw new IOException("找不到可写的安装临时目录。请把安装包移到可写的磁盘后重试。", last);
    }
    static void Extract(string self, string output) {
        using(var input = File.OpenRead(self)) {
            int footer = 8 + 32 + Magic.Length;
            if(input.Length < footer) throw new InvalidDataException("安装包不完整，请重新下载。");
            input.Position = input.Length - footer;
            var reader = new BinaryReader(input);
            long length = reader.ReadInt64(); byte[] expected = reader.ReadBytes(32), magic = reader.ReadBytes(Magic.Length);
            if(!Equal(magic, Magic) || length <= 0 || length > input.Length - footer) throw new InvalidDataException("安装包尾部校验失败，请重新下载。");
            input.Position = input.Length - footer - length;
            using(var hash = SHA256.Create()) using(var target = new FileStream(output, FileMode.CreateNew, FileAccess.Write, FileShare.None)) {
                byte[] buffer = new byte[1024 * 1024]; long remaining = length;
                while(remaining > 0) {
                    int count = input.Read(buffer, 0, (int)Math.Min(buffer.Length, remaining));
                    if(count == 0) throw new EndOfStreamException("安装包不完整，请重新下载。");
                    hash.TransformBlock(buffer, 0, count, buffer, 0); target.Write(buffer, 0, count); remaining -= count;
                }
                hash.TransformFinalBlock(new byte[0], 0, 0);
                if(!Equal(expected, hash.Hash)) throw new InvalidDataException("安装包SHA256校验失败，请重新下载。");
            }
        }
    }
    static bool Equal(byte[] a, byte[] b) { if(a.Length != b.Length) return false; int different = 0; for(int i = 0; i < a.Length; i++) different |= a[i] ^ b[i]; return different == 0; }
    [STAThread] static int Main(string[] args) {
        string session = null, extracted = null; bool silent = false;
        foreach(string arg in args) if(arg.Equals("/SILENT", StringComparison.OrdinalIgnoreCase) || arg.Equals("/VERYSILENT", StringComparison.OrdinalIgnoreCase)) silent = true;
        try {
            string self = Assembly.GetExecutingAssembly().Location;
#if UNINSTALL
            string uninstallRoot = Path.GetDirectoryName(self);
            bool detached = args.Length >= 2 && args[0].StartsWith("/ABHOSTSOURCE=", StringComparison.Ordinal);
            if(detached) {
                uninstallRoot = args[0].Substring(14);
                int parent = Int32.Parse(args[1].Substring(14));
                try { using(var previous = Process.GetProcessById(parent)) if(!previous.WaitForExit(10000)) throw new IOException("卸载入口仍在退出，请稍后重试。"); } catch(ArgumentException) {}
                var forwarded = new string[args.Length - 2]; Array.Copy(args, 2, forwarded, 0, forwarded.Length); args = forwarded;
            }
#endif
            session = Session(self);
            string trace = Path.Combine(session, "host.log");
            File.WriteAllText(trace, "temp=" + session + "\r\nparent_temp=" + Environment.GetEnvironmentVariable("TEMP") + "\r\n");
            string app;
#if UNINSTALL
            if(!detached) {
                // Release the installed host's image lock before removing app files.
                string copy = Path.Combine(session, "Uninstall.exe"); File.Copy(self, copy);
                var forward = new StringBuilder(Quote("/ABHOSTSOURCE=" + uninstallRoot) + " " + Quote("/ABHOSTPARENT=" + Process.GetCurrentProcess().Id));
                foreach(string arg in args) forward.Append(' ').Append(Quote(arg));
                var child = new ProcessStartInfo(copy, forward.ToString()); child.UseShellExecute = false;
                child.EnvironmentVariables["TEMP"] = session; child.EnvironmentVariables["TMP"] = session;
                using(var launched = Process.Start(child)) File.AppendAllText(trace, "detached_pid=" + launched.Id + "\r\n");
                return 0;
            }
            app = Path.Combine(uninstallRoot, "unins000.exe");
            if(!File.Exists(app)) throw new FileNotFoundException("找不到卸载程序。请先用完整安装包修复。", app);
#else
            extracted = Path.Combine(session, "Setup.exe");
            Extract(self, extracted); app = extracted;
#endif
            var arguments = new StringBuilder(); bool hasLog = false;
            foreach(string arg in args) { arguments.Append(Quote(arg)).Append(' '); if(arg.Equals("/LOG", StringComparison.OrdinalIgnoreCase) || arg.StartsWith("/LOG=", StringComparison.OrdinalIgnoreCase)) hasLog = true; }
            if(!hasLog) arguments.Append(Quote("/LOG=" + Path.Combine(session, "setup.log")));
            var info = new ProcessStartInfo(app, arguments.ToString());
            info.UseShellExecute = false; info.WorkingDirectory = Path.GetDirectoryName(self);
            info.EnvironmentVariables["TEMP"] = session; info.EnvironmentVariables["TMP"] = session;
            using(var process = Process.Start(info)) {
                process.WaitForExit(); int code = process.ExitCode;
                File.AppendAllText(trace, "exit=" + code + "\r\n"); return code;
            }
        } catch(Exception error) {
            string message = "安装或卸载未完成：" + error.Message;
            if(session != null) try { File.AppendAllText(Path.Combine(session, "host.log"), "error=" + error + "\r\n"); } catch {}
            if(!silent) MessageBox.Show(message, "诡异事务局", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        } finally {
            // Only remove the payload this process created. Keep diagnostic logs.
            if(extracted != null) try { File.Delete(extracted); } catch {}
        }
    }
}
