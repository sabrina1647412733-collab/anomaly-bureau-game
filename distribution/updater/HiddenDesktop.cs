// Acceptance process isolation. Never switches desktops; all descendant windows
// stay on a private non-input desktop. Fail closed if isolation is unavailable.
using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
class HiddenDesktop {
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Startup {
        public int cb; public string reserved,desktop,title;
        public int x,y,xSize,ySize,xCount,yCount,fill,flags; public short show,reserved2;
        public IntPtr reservedPtr,input,output,error;
    }
    [StructLayout(LayoutKind.Sequential)] struct Info {public IntPtr process,thread;public int pid,tid;}
    [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateDesktop(string name,IntPtr device,IntPtr devmode,int flags,uint access,IntPtr security);
    [DllImport("user32.dll")] static extern bool CloseDesktop(IntPtr desk);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcess(string app,StringBuilder command,IntPtr processAttrs,IntPtr threadAttrs,bool inherit,uint flags,IntPtr environment,string cwd,ref Startup startup,out Info info);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle,uint timeout);
    [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr handle,out uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    static string Quote(string v){var s=new StringBuilder("\"");int n=0;foreach(char c in v){if(c=='\\'){n++;continue;}s.Append('\\',c=='"'?n*2+1:n);s.Append(c);n=0;}s.Append('\\',n*2);return s.Append('"').ToString();}
    public static int Main(string[] args){
        if(args.Length<2)return 2;
        string status=Path.GetFullPath(args[0]),app=Path.GetFullPath(args[1]);
        if(!status.StartsWith("F:\\",StringComparison.OrdinalIgnoreCase))return 3;
        string name="AnomalyBureauTest_"+Guid.NewGuid().ToString("N");
        IntPtr desk=CreateDesktop(name,IntPtr.Zero,IntPtr.Zero,0,0x1FF,IntPtr.Zero);
        if(desk==IntPtr.Zero){File.WriteAllText(status,"isolation_failed="+Marshal.GetLastWin32Error());return 4;}
        try{
            var cmd=new StringBuilder(Quote(app));for(int i=2;i<args.Length;i++)cmd.Append(" "+Quote(args[i]));
            var start=new Startup{desktop=name,flags=1,show=0};start.cb=Marshal.SizeOf(start);Info info;
            if(!CreateProcess(app,cmd,IntPtr.Zero,IntPtr.Zero,false,0x08000000,IntPtr.Zero,Path.GetDirectoryName(app),ref start,out info)){File.WriteAllText(status,"launch_failed="+Marshal.GetLastWin32Error());return 5;}
            CloseHandle(info.thread);
            try{File.WriteAllText(status,"isolated_desktop=true\nroot_pid="+info.pid);WaitForSingleObject(info.process,0xFFFFFFFF);uint code;GetExitCodeProcess(info.process,out code);File.AppendAllText(status,"\nexit="+code);return (int)code;}finally{CloseHandle(info.process);}
        }finally{CloseDesktop(desk);}
    }
}
