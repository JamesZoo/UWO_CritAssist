namespace CountDown.Host
{
    using System.Runtime.CompilerServices;

    public partial class MainWindow
    {
        private KeyboardHook keyboardHook;

        private void InitializeKeyboardHook()
        {
            this.ReleaseKeyboardHook();

            keyboardHook = new KeyboardHook();
            keyboardHook.KeyDown += MeleeCountDownKeyHook;
        }

        private void ReleaseKeyboardHook()
        {
            if (keyboardHook != null)
            {
                keyboardHook.KeyDown -= this.MeleeCountDownKeyHook;
                keyboardHook.Dispose();
                keyboardHook = null;
            }
        }

        private void MeleeCountDownKeyHook(VKeys key)
        {
            switch (key)
            {
                case VKeys.KEY_Q:
                    this.OnQPressed();
                    break;

                case VKeys.KEY_E:
                    this.OnEPressed();
                    break;

                case VKeys.ESCAPE:
                    this.OnEPressed();
                    break;

                default:
                    // Do nothing for now
                    break;
            }
        }
    }
}
