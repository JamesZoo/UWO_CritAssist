namespace CountDown.Host
{
    using System;
    using System.Windows.Interop;

    public partial class MainWindow
    {
        private HwndSource source;
        private const int HOTKEY_ID_Q = 9000;
        private const int HOTKEY_ID_E = 9001;
        private const int HOTKEY_ID_ESC = 9002;

        private void InitializeHotkeys()
        {
            // Initializing - Listening keyboard events using  Windows Global Hotkey approach
            var helper = new WindowInteropHelper(this);
            this.source = HwndSource.FromHwnd(helper.Handle);
            this.source.AddHook(HwndHook);
            RegisterHotKey();
        }

        private void ReleaseHotkeys()
        {
            // Cleaning up - Listening keyboard events using  Windows Global Hotkey approach
            this.source.RemoveHook(HwndHook);
            this.source = null;
            UnregisterHotKey();
        }

        private void RegisterHotKey()
        {
            var helper = new WindowInteropHelper(this);
            const uint VK_Q = 0x51;
            const uint VK_E = 0x45;
            const uint VK_ESC = 0x1B;
            
            const uint MOD_NONE = 0x0000;
            if(!NativeMethods.RegisterHotKey(helper.Handle, HOTKEY_ID_Q, MOD_NONE, VK_Q))
            {
                // handle error
            }

            if(!NativeMethods.RegisterHotKey(helper.Handle, HOTKEY_ID_E, MOD_NONE, VK_E))
            {
                // handle error
            }

            if(!NativeMethods.RegisterHotKey(helper.Handle, HOTKEY_ID_ESC, MOD_NONE, VK_ESC))
            {
                // handle error
            }
        }

        private void UnregisterHotKey()
        {
            var helper = new WindowInteropHelper(this);
            NativeMethods.UnregisterHotKey(helper.Handle, HOTKEY_ID_Q);
            NativeMethods.UnregisterHotKey(helper.Handle, HOTKEY_ID_E);
            NativeMethods.UnregisterHotKey(helper.Handle, HOTKEY_ID_ESC);
        }

        private IntPtr HwndHook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            const int WM_HOTKEY = 0x0312;
            switch(msg)
            {
                case WM_HOTKEY:
                    switch(wParam.ToInt32())
                    {
                        case HOTKEY_ID_Q:
                            OnQPressed();
                            handled = true;
                            break;
                        case HOTKEY_ID_E:
                            OnEPressed();
                            handled = true;
                            break;

                        case HOTKEY_ID_ESC:
                            OnEscPressed();
                            handled = true;
                            break;
                    }
                    break;
            }
            return IntPtr.Zero;
        }
    }
}
