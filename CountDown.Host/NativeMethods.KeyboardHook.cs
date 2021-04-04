namespace CountDown.Host
{
    using System;
    using System.Runtime.InteropServices;

    internal delegate IntPtr KeyboardHookHandler(int nCode, IntPtr wParam, IntPtr lParam);

    internal static partial class NativeMethods
    {
        public const int WM_KEYDOWN = 0x100;
        public const int WM_SYSKEYDOWN = 0x104;
        public const int WM_KEYUP = 0x101;
        public const int WM_SYSKEYUP = 0x105;

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern IntPtr SetWindowsHookEx(int idHook, KeyboardHookHandler lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern IntPtr GetModuleHandle(string lpModuleName);
    }
}