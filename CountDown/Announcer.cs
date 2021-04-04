namespace CountDown
{
    using System;
    using System.Globalization;
    using System.Runtime.Remoting.Messaging;
    using System.Speech.Synthesis;
    using System.Threading;
    using System.Threading.Tasks;

    public sealed class Announcer : IAnnouncer, IDisposable
    {
        public const int DefaultRate = 100;
        public const int DefaultPitch = 0;
        public const int DefaultVolume = 10;

        private readonly SpeechSynthesizer speechSynthesizer = new SpeechSynthesizer();

        public Announcer()
        {
            speechSynthesizer.SelectVoiceByHints(VoiceGender.Female, VoiceAge.Child);
        }

        public async Task AnnounceAsync(string text)
        {
            await this.AnnounceAsync(text, 0, 100);
        }

        public async Task AnnounceAsync(string text, int pitch, int ratePercent)
        {
            await this.AnnounceAsync(text, pitch, ratePercent, false);
        }

        public async Task AnnounceAsync(string text, int pitch, int ratePercent, bool forced)
        {
            try
            {
                await Task.Run(
                    () =>
                    {
                        if (speechSynthesizer.State == SynthesizerState.Ready || forced)
                        {
                            speechSynthesizer.SpeakSsml(this.GenerateSsml(text, pitch, ratePercent));
                        }
                    },
                    CancellationToken.None);
            }
            catch (ObjectDisposedException)
            {
                // Ignore
            }
            catch (OperationCanceledException)
            {
                // Ignore
            }
        }

        public void Dispose()
        {
            speechSynthesizer.Dispose();
        }

        private string GenerateSsml(string text, int pitch, int ratePercent)
        {
            string ssml = "<speak version=\"1.0\"";
            ssml += " xmlns=\"http://www.w3.org/2001/10/synthesis\"";
            ssml += " xml:lang=\"en-US\">";
            ssml += $"<prosody volume=\"x-loud\" rate=\"{ratePercent}%\" pitch=\"{pitch}st\">{text}</prosody>";
            ssml += "</speak>";

            return ssml;
        }
    }
}
