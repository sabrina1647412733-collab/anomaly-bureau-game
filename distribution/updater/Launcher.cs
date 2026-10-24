// Stable bootstrapper/updater. Builds with the Windows .NET Framework 4.x compiler.
// Payload protocol 1 deliberately allows ONLY the two Godot runtime files.
using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;
using System.Security.Cryptography;
using System.Web.Script.Serialization;
using System.IO.Compression;
using System.Windows.Forms;

namespace AnomalyBureauDistribution {
public sealed class PayloadFile { public string path; public long size; public string sha256; }
public sealed class Manifest { public int protocol; public string version; public PayloadFile[] files; }
public sealed class Job {
    public string install_dir, archive, sha256, version, token;
    public int parent_pid;
    public string[] game_args;
}
public sealed class Journal {
    public string state, version, token, error;
    public int child_pid;
    public string[] game_args;
    public List<string> touched = new List<string>();
    public List<string> existed = new List<string>();
}
public static class Launcher {
    internal static readonly string[] Allowed = { "AnomalyBureau.Game.exe", "AnomalyBureau.Game.pck" };
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
    internal static Action<string> Fault; // Test-only injection; not exposed on the command line.
    internal static int HealthSeconds = 120;
    static string Cache(string root) { return Path.Combine(root, "_更新缓存"); }
    static string JournalPath(string root) { return Path.Combine(Cache(root), "transaction.json"); }
    internal static string Hash(string path) {
        using (var f = File.OpenRead(path)) using (var sha = SHA256.Create())
            return BitConverter.ToString(sha.ComputeHash(f)).Replace("-", "").ToLowerInvariant();
    }
    internal static void WriteJson(string path, object value) {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        string tmp = path + ".tmp";
        byte[] data = Encoding.UTF8.GetBytes(Json.Serialize(value));
        using (var f = new FileStream(tmp, FileMode.Create, FileAccess.Write, FileShare.None)) {
            f.Write(data, 0, data.Length); f.Flush(true);
        }
        if (File.Exists(path)) File.Replace(tmp, path, null); else File.Move(tmp, path);
    }
    internal static T Read<T>(string path) { return Json.Deserialize<T>(File.ReadAllText(path, Encoding.UTF8)); }
    static void Hit(string point) { if (Fault != null) Fault(point); }
    static void EnsurePlain(string path) {
        string p = Path.GetFullPath(path);
        while (!String.IsNullOrEmpty(p)) {
            if ((Directory.Exists(p) || File.Exists(p)) && (File.GetAttributes(p) & FileAttributes.ReparsePoint) != 0)
                throw new IOException("不允许通过符号链接或目录联接更新：" + p);
            p = Path.GetDirectoryName(p);
        }
    }
    internal static Manifest Stage(string root, Job job) {
        EnsurePlain(root); EnsurePlain(Cache(root));
        if (!System.Text.RegularExpressions.Regex.IsMatch(job.version ?? "", @"^\d+\.\d+\.\d+$"))
            throw new InvalidDataException("版本号无效");
        if (!System.Text.RegularExpressions.Regex.IsMatch(job.sha256 ?? "", "^[a-fA-F0-9]{64}$") || Hash(job.archive) != job.sha256.ToLowerInvariant())
            throw new InvalidDataException("更新包 SHA256 校验失败，请重试下载。");
        string stage = Path.Combine(Cache(root), "stage");
        if (Directory.Exists(stage)) Directory.Delete(stage, true);
        Directory.CreateDirectory(stage);
        using (var zip = ZipFile.OpenRead(job.archive)) {
            if (zip.Entries.Count != 3) throw new InvalidDataException("更新包必须只含清单和两份游戏文件");
            var entry = zip.GetEntry("manifest.json");
            if (entry == null || entry.Length > 65536) throw new InvalidDataException("缺少更新清单");
            Manifest manifest;
            using (var reader = new StreamReader(entry.Open())) manifest = Json.Deserialize<Manifest>(reader.ReadToEnd());
            if (manifest == null || manifest.protocol != 1 || manifest.version != job.version || manifest.files == null || manifest.files.Length != 2)
                throw new InvalidDataException("更新清单协议或版本不匹配");
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var item in manifest.files) {
                if (!Allowed.Contains(item.path) || !seen.Add(item.path) || item.size <= 0 || item.size > 4294967296L)
                    throw new InvalidDataException("更新清单包含非法文件");
                var fileEntry = zip.GetEntry(item.path);
                if (fileEntry == null || fileEntry.Length != item.size) throw new InvalidDataException("文件长度不匹配");
                string dest = Path.Combine(stage, item.path);
                fileEntry.ExtractToFile(dest);
                if (Hash(dest) != item.sha256) throw new InvalidDataException("游戏文件校验失败：" + item.path);
            }
            // Reject duplicate ZIP names and extra entries even when they are not extracted.
            if (zip.Entries.Select(e => e.FullName).Distinct(StringComparer.OrdinalIgnoreCase).Count() != 3)
                throw new InvalidDataException("重复的 ZIP 条目");
            return manifest;
        }
    }
    internal static void Apply(string root, Job job) {
        Stage(root, job); // Old game still intact on EVERY staging/validation failure.
        string backup = Path.Combine(Cache(root), "backup");
        EnsurePlain(backup);
        if (Directory.Exists(backup)) Directory.Delete(backup, true);
        Directory.CreateDirectory(backup);
        var j = new Journal { state="applying", version=job.version, token=job.token, game_args=job.game_args ?? new string[0] };
        foreach (string name in Allowed) {
            EnsurePlain(Path.Combine(root, name));
            if (File.Exists(Path.Combine(root, name))) {
                File.Copy(Path.Combine(root, name), Path.Combine(backup, name));
                j.existed.Add(name);
            }
        }
        WriteJson(JournalPath(root), j); // Full backup exists BEFORE any replacement.
        try {
            foreach (string name in Allowed) {
                j.touched.Add(name); WriteJson(JournalPath(root), j); // Write-ahead intent.
                File.Copy(Path.Combine(Cache(root), "stage", name), Path.Combine(root, name), true);
                Hit("replaced:" + name);
            }
            j.state = "launching"; WriteJson(JournalPath(root), j);
        } catch { Rollback(root, j, "替换文件失败，已恢复旧版本。"); throw; }
    }
    internal static void Rollback(string root, Journal j, string reason) {
        EnsurePlain(root); EnsurePlain(Cache(root));
        EnsurePlain(Path.Combine(Cache(root),"backup"));
        j.state="rolling_back"; j.error=reason; WriteJson(JournalPath(root), j);
        foreach (string name in j.touched) {
            if (!Allowed.Contains(name)) throw new InvalidDataException("回滚清单含非法路径");
            string dest=Path.Combine(root,name); EnsurePlain(dest);
            if (j.existed.Contains(name)) File.Copy(Path.Combine(Cache(root),"backup",name),dest,true);
            else if (File.Exists(dest)) File.Delete(dest);
        }
        j.state="rolled_back"; WriteJson(JournalPath(root),j);
        WriteJson(Path.Combine(Cache(root),"result.json"),new { status="rolled_back", version=j.version, message=reason });
    }
    internal static bool Recover(string root) {
        if (!File.Exists(JournalPath(root))) return false;
        var j=Read<Journal>(JournalPath(root));
        if (j.state=="committed" || j.state=="rolled_back") return false;
        // Do not replace files of a surviving new-version game after a helper crash.
        if (j.child_pid>0) {
            try {
                var p=Process.GetProcessById(j.child_pid);
                if (!p.HasExited && String.Equals(p.MainModule.FileName,Path.Combine(root,Allowed[0]),StringComparison.OrdinalIgnoreCase))
                    throw new IOException("请先正常退出游戏，再启动以恢复上一次未完成的更新。");
            } catch (ArgumentException) { }
        }
        Rollback(root,j,"上次更新未完成，已恢复旧版本，可在游戏中重试。");
        return true;
    }
    internal static string Quote(string value) {
        // CommandLineToArgvW-compatible quoting, including paths ending in a backslash.
        var s=new StringBuilder("\""); int slashes=0;
        foreach (char c in value) {
            if (c=='\\') { slashes++; continue; }
            if (c=='\"') { s.Append('\\',slashes*2+1); s.Append(c); }
            else { s.Append('\\',slashes); s.Append(c); }
            slashes=0;
        }
        s.Append('\\',slashes*2); s.Append('"'); return s.ToString();
    }
    static Process StartGame(string root, string[] args) {
        return Process.Start(new ProcessStartInfo(Path.Combine(root,Allowed[0]),String.Join(" ",args.Select(Quote))) {
            WorkingDirectory=root, UseShellExecute=false
        });
    }
    internal static bool Confirm(string root, Job job) {
        string health=Path.Combine(Cache(root),"health.txt");
        if (File.Exists(health)) File.Delete(health);
        var j=Read<Journal>(JournalPath(root));
        var args=new List<string>(job.game_args ?? new string[0]);
        // Godot engine options must precede its user-argument separator.
        int sep=args.IndexOf("--"); if (sep<0) args.Add("--");
        args.Add("--update-health="+health); args.Add("--update-token="+job.token);
        Process child=null;
        try {
            child=StartGame(root,args.ToArray());
            j.child_pid=child.Id; WriteJson(JournalPath(root),j);
            var timer=Stopwatch.StartNew();
            while (timer.Elapsed.TotalSeconds<HealthSeconds && !child.HasExited) {
                if (File.Exists(health) && File.ReadAllText(health).Trim()==job.token) {
                    Thread.Sleep(2000);
                    if (!child.HasExited) {
                        j.state="committed"; WriteJson(JournalPath(root),j);
                        WriteJson(Path.Combine(Cache(root),"result.json"),new {status="committed",version=job.version,message="更新完成"});
                        return true;
                    }
                    break;
                }
                Thread.Sleep(250);
            }
            // This child was created by this transaction, never an unrelated player process.
            if (!child.HasExited) { child.Kill(); if (!child.WaitForExit(10000)) throw new IOException("新进程无法结束，稍后通过启动器恢复。"); }
            Rollback(root,j,"新版本未能正常进入主菜单，已恢复旧版本。");
            return false;
        } catch {
            if (child!=null && !child.HasExited) { child.Kill(); child.WaitForExit(10000); }
            Rollback(root,j,"新版本启动失败，已恢复旧版本。"); throw;
        }
    }
    [STAThread] public static int Main(string[] args) {
        try {
            if (args.Length==2 && args[0]=="--apply") {
                Job job=Read<Job>(args[1]); string root=Path.GetFullPath(job.install_dir);
                EnsurePlain(root); EnsurePlain(Cache(root));
                if (String.IsNullOrEmpty(job.token) || job.token.Length!=32) throw new InvalidDataException("更新令牌无效");
                using (var gate=new FileStream(Path.Combine(Cache(root),"update.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None)) {
                    File.WriteAllText(Path.Combine(Cache(root),"ready-"+job.token+".txt"),job.token);
                    // Parent PID is also tied to its executable path to avoid PID-reuse waits.
                    try {
                        var parent=Process.GetProcessById(job.parent_pid);
                        if (String.Equals(parent.MainModule.FileName,Path.Combine(root,Allowed[0]),StringComparison.OrdinalIgnoreCase) && !parent.WaitForExit(60000))
                            throw new IOException("游戏尚未退出，更新已取消。请退出游戏后重试。");
                    } catch (ArgumentException) { }
                    Recover(root);
                    try {
                        Apply(root,job);
                        if (!Confirm(root,job)) StartGame(root,job.game_args ?? new string[0]);
                    } catch (Exception e) {
                        WriteJson(Path.Combine(Cache(root),"result.json"),new {status="failed",version=job.version,message=e.Message});
                        // Only start a known-restored game. An incomplete rollback requires recovery.
                        if (!File.Exists(JournalPath(root)) || new[]{"committed","rolled_back"}.Contains(Read<Journal>(JournalPath(root)).state))
                            StartGame(root,job.game_args ?? new string[0]);
                        throw;
                    }
                }
            } else {
                string root=AppDomain.CurrentDomain.BaseDirectory;
                EnsurePlain(root); Directory.CreateDirectory(Cache(root)); EnsurePlain(Cache(root));
                using (var gate=new FileStream(Path.Combine(Cache(root),"update.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None)) {
                    Recover(root); StartGame(root,args);
                }
            }
            return 0;
        } catch (Exception e) {
            MessageBox.Show("更新或启动未完成：\n"+e.Message+"\n\n请关闭游戏后重新启动 AnomalyBureau.exe。存档与设置未被更新器修改。", "诡异事务局",MessageBoxButtons.OK,MessageBoxIcon.Warning);
            return 1;
        }
    }
}}
