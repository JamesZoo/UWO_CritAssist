namespace CountDown.Host
{
    using System;
    using System.Runtime.InteropServices;

    internal static partial class NativeMethods
    {
        [DllImport("user32.dll")]
        public static extern bool RegisterHotKey(IntPtr windowHandle, int hotkeyId, uint modifierKeys, uint virtualKey);

        [DllImport("user32.dll")]
        public static extern bool UnregisterHotKey(IntPtr windowHandle, int hotkeyId);
    }
}
