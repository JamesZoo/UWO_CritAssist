namespace CountDown.Test
{
    using System.Threading.Tasks;
    using Microsoft.VisualStudio.TestTools.UnitTesting;

    [TestClass]
    public sealed class AnnouncerTests
    {
        [TestMethod]
        public async Task Announce_SingleWord_WithInterval()
        {

            using (var announcer = new Announcer())
            {
                announcer.AnnounceAsync("Activating count down.", 10, 120);
                await Task.Delay(1000);

                for (int i = 0; i < 3; ++i)
                {
                    announcer.AnnounceAsync("Five", -5, 200);
                    await Task.Delay(1000);
                    announcer.AnnounceAsync("Four", -5, 200);
                    await Task.Delay(1000);
                    announcer.AnnounceAsync("three",-5, 200);
                    await Task.Delay(1000);
                    announcer.AnnounceAsync("two", -5, 200);
                    await Task.Delay(1000);
                    announcer.AnnounceAsync("One", -5, 200);
                    await Task.Delay(1000);
                    announcer.AnnounceAsync("Attack", 10, 200);
                    await Task.Delay(1000);
                    announcer.AnnounceAsync("Defence", 10, 200);
                    await Task.Delay(1000);
                }
            }
        }

        [TestMethod]
        public async Task Announce_UsingPitch()
        {
            using (var announcer = new Announcer())
            {
                string word = "Fire in the hole!";

                var highPitch = 10;
                await announcer.AnnounceAsync("Speaking with high pitch");
                await announcer.AnnounceAsync(word, highPitch, Announcer.DefaultRate);

                var lowPitch = -10;
                await announcer.AnnounceAsync("Speaking with low pitch");
                await announcer.AnnounceAsync(word, lowPitch, Announcer.DefaultRate);
            }
        }


        [TestMethod]
        public async Task Announce_Sentence_WithDifferentRate()
        {
            string sentence = "I would like to have a piece of cheese at the earliest possible moment.";
            using (var announcer = new Announcer())
            {
                await announcer.AnnounceAsync("Using slow speech rate.");
                await announcer.AnnounceAsync(sentence, Announcer.DefaultPitch, 50);
            }

            using (var announcer = new Announcer())
            {
                await announcer.AnnounceAsync("Using normal speech rate.");
                await announcer.AnnounceAsync(sentence, Announcer.DefaultPitch, Announcer.DefaultRate);
            }

            using (var announcer = new Announcer())
            {
                await announcer.AnnounceAsync("Using fast speech rate.");
                await announcer.AnnounceAsync(sentence, Announcer.DefaultPitch, 150);
            }
        }
    }
}
