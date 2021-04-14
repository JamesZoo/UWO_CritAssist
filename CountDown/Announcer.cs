using System.Collections.Concurrent;
using System.Collections.Generic;

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
        private readonly ConcurrentBag<SpeechSynthesizer> speechSynthesizers = new ConcurrentBag<SpeechSynthesizer>();
        private readonly List<SpeechSynthesizer> speechSynthesizersTracker = new List<SpeechSynthesizer>();

        public Announcer()
        {
            for (int i = 0; i < 10; ++i)
            {
                var synthesizer = new SpeechSynthesizer();
                synthesizer.SelectVoiceByHints(VoiceGender.Female, VoiceAge.Child);
                this.speechSynthesizers.Add(synthesizer);
                this.speechSynthesizersTracker.Add(synthesizer);
            }
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
                        if (!speechSynthesizers.TryTake(out var speechSynthesizer))
                        {
                            return;
                        }

                        speechSynthesizer.SpeakSsml(this.GenerateSsml(text, pitch, ratePercent));
                        this.speechSynthesizers.Add(speechSynthesizer);
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
            foreach (var speechSynthesizer in speechSynthesizersTracker)
            {
                speechSynthesizer.Dispose();
            }
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
