// Fixture used only by test_updater.ps1; never distributed.
using System;
using System.IO;
using System.Threading;
class HealthGame {
    static int Main(string[] args) {
        if (Array.IndexOf(args,"--fail")>=0) return 2;
        string health=null,token=null;
        foreach(var arg in args) {
            if(arg.StartsWith("--update-health=")) health=arg.Substring(16);
            if(arg.StartsWith("--update-token=")) token=arg.Substring(15);
        }
        if(health!=null) File.WriteAllText(health,token);
        Thread.Sleep(3500); return 0;
    }
}
