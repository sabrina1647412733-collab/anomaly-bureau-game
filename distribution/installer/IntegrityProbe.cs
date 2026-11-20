using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

// Read-only mandatory integrity label queries; no privileges are enabled.
// The file API is deliberately native: GetSddlForm can omit mandatory labels.
public static class AnomalyInstallerIntegrity
{
    private const uint LabelSecurityInformation = 0x00000010;
    private const byte SystemMandatoryLabelAceType = 0x11;
    private const uint TokenQuery = 0x0008;
    private const int TokenIntegrityLevel = 25;
    private const int ErrorInsufficientBuffer = 122;
    private const int MediumIntegrityRid = 8192;

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetFileSecurityW(string fileName, uint requestedInformation,
        IntPtr securityDescriptor, uint length, out uint lengthNeeded);

    [DllImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetSecurityDescriptorSacl(IntPtr securityDescriptor,
        [MarshalAs(UnmanagedType.Bool)] out bool saclPresent, out IntPtr sacl,
        [MarshalAs(UnmanagedType.Bool)] out bool saclDefaulted);

    [DllImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetAce(IntPtr acl, uint aceIndex, out IntPtr ace);

    [DllImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsValidSid(IntPtr sid);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern IntPtr GetSidSubAuthorityCount(IntPtr sid);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern IntPtr GetSidSubAuthority(IntPtr sid, uint subAuthority);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();

    [DllImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool OpenProcessToken(IntPtr process, uint desiredAccess, out IntPtr token);

    [DllImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetTokenInformation(IntPtr token, int informationClass,
        IntPtr tokenInformation, uint length, out uint returnLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CloseHandle(IntPtr handle);

    private static int LastSidRid(IntPtr sid)
    {
        if (sid == IntPtr.Zero || !IsValidSid(sid))
            throw new InvalidOperationException("Invalid integrity label SID.");
        IntPtr countPtr = GetSidSubAuthorityCount(sid);
        if (countPtr == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        byte count = Marshal.ReadByte(countPtr);
        if (count == 0) throw new InvalidOperationException("Integrity SID has no RID.");
        IntPtr ridPtr = GetSidSubAuthority(sid, (uint)(count - 1));
        if (ridPtr == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        return Marshal.ReadInt32(ridPtr);
    }

    public static int FileIntegrity(string path)
    {
        if (String.IsNullOrEmpty(path)) throw new ArgumentException("A file or directory path is required.", "path");
        uint needed;
        if (GetFileSecurityW(path, LabelSecurityInformation, IntPtr.Zero, 0, out needed))
            throw new InvalidOperationException("Unexpected empty security descriptor.");
        int error = Marshal.GetLastWin32Error();
        if (error != ErrorInsufficientBuffer || needed == 0) throw new Win32Exception(error);
        IntPtr descriptor = Marshal.AllocHGlobal(checked((int)needed));
        try
        {
            uint actual;
            if (!GetFileSecurityW(path, LabelSecurityInformation, descriptor, needed, out actual))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            bool present, defaulted;
            IntPtr acl;
            if (!GetSecurityDescriptorSacl(descriptor, out present, out acl, out defaulted))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            if (!present || acl == IntPtr.Zero) return MediumIntegrityRid;
            // ACL header stores AceCount as a WORD at offset 4.
            ushort aceCount = unchecked((ushort)Marshal.ReadInt16(acl, 4));
            for (uint i = 0; i < aceCount; i++)
            {
                IntPtr ace;
                if (!GetAce(acl, i, out ace)) throw new Win32Exception(Marshal.GetLastWin32Error());
                if (ace != IntPtr.Zero && Marshal.ReadByte(ace) == SystemMandatoryLabelAceType)
                {
                    // SYSTEM_MANDATORY_LABEL_ACE: four-byte ACE_HEADER, four-byte
                    // mask, followed by the SID, independent of process bitness.
                    return LastSidRid(IntPtr.Add(ace, 8));
                }
            }
            return MediumIntegrityRid;
        }
        finally { Marshal.FreeHGlobal(descriptor); }
    }

    public static int CurrentProcessIntegrity()
    {
        IntPtr token;
        if (!OpenProcessToken(GetCurrentProcess(), TokenQuery, out token))
            throw new Win32Exception(Marshal.GetLastWin32Error());
        try
        {
            uint needed;
            if (GetTokenInformation(token, TokenIntegrityLevel, IntPtr.Zero, 0, out needed))
                throw new InvalidOperationException("Unexpected empty token information.");
            int error = Marshal.GetLastWin32Error();
            if (error != ErrorInsufficientBuffer || needed == 0) throw new Win32Exception(error);
            IntPtr info = Marshal.AllocHGlobal(checked((int)needed));
            try
            {
                uint actual;
                if (!GetTokenInformation(token, TokenIntegrityLevel, info, needed, out actual))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                // TOKEN_MANDATORY_LABEL begins with SID_AND_ATTRIBUTES; its first
                // member is a pointer to the integrity SID.
                return LastSidRid(Marshal.ReadIntPtr(info));
            }
            finally { Marshal.FreeHGlobal(info); }
        }
        finally { CloseHandle(token); }
    }
}
