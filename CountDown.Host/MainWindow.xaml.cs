
namespace CountDown.Host
{
    using System;
    using System.Windows;
    using System.Windows.Interop;

    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        private readonly Announcer announcer = new Announcer();
        private readonly UwoMeleeCountDownHelper countDownHelper;

        public MainWindow()
        {
            InitializeComponent();
            this.countDownHelper = new UwoMeleeCountDownHelper(this.announcer);
        }

        protected override void OnSourceInitialized(EventArgs e)
        {
            base.OnSourceInitialized(e);

            this.InitializeKeyboardHook();
        }

        protected override void OnClosed(EventArgs e)
        {
            this.ReleaseKeyboardHook();

            countDownHelper.StopCountDown();
            this.announcer.Dispose();

            base.OnClosed(e);
        }

        private void OnQPressed()
        {
            this.countDownHelper.StartCountDown(firstMelee: true);
        }

        private void OnEPressed()
        {
            this.countDownHelper.StartCountDown(firstMelee: false);
        }

        private void OnEscPressed()
        {
            countDownHelper.StopCountDown();
        }
    }
}
