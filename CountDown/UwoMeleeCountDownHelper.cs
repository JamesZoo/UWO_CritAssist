namespace CountDown
{
    using System;
    using System.Runtime.CompilerServices;
    using System.Threading.Tasks;
    using System.Threading;

    public sealed class UwoMeleeCountDownHelper
    {
        private enum CountingState
        {
            None,
            Activate,
            Seven,
            Six,
            Five,
            Four,
            Three,
            Two,
            One,
            Attack,
            Defense,
        }

        private readonly IAnnouncer announcer;
        private long count;

        public UwoMeleeCountDownHelper(IAnnouncer announcer)
        {
            this.announcer = announcer ?? throw new ArgumentNullException(nameof(announcer));
        }

        public async void StartCountDown(bool firstMelee)
        {
            var currentCount = Interlocked.Increment(ref this.count);
            var countingState = CountingState.Activate;
            while (this.count == currentCount)
            {
                switch (countingState)
                {
                    case CountingState.Activate:
                        if (firstMelee)
                        {
                            announcer.AnnounceAsync("First round", 10, 120, true);
                            countingState = CountingState.Four;
                        }
                        else
                        {
                            announcer.AnnounceAsync("On going", 10, 120, true);
                            countingState = CountingState.Five;
                        }

                        await Task.Delay(1000);
                        break;

                    case CountingState.Seven:
                        announcer.AnnounceAsync("Seven", -5, 100);
                        countingState = CountingState.Six;
                        await Task.Delay(1000);
                        break;

                    case CountingState.Six:
                        announcer.AnnounceAsync("Six", -5, 100);
                        countingState = CountingState.Five;
                        await Task.Delay(1000);
                        break;

                    case CountingState.Five:
                        announcer.AnnounceAsync("Five", -5, 100);
                        countingState = CountingState.Four;
                        await Task.Delay(1000);
                        break;

                    case CountingState.Four:
                        announcer.AnnounceAsync("Four", -5, 100);
                        countingState = CountingState.Three;
                        await Task.Delay(1000);
                        break;

                    case CountingState.Three:
                        announcer.AnnounceAsync("Three", -5, 100);
                        countingState = CountingState.Two;
                        await Task.Delay(1000);

                        break;
                    case CountingState.Two:
                        announcer.AnnounceAsync("Two", -5, 100);
                        countingState = CountingState.One;
                        await Task.Delay(1000);
                        break;

                    case CountingState.One:
                        announcer.AnnounceAsync("One", -5, 100);
                        countingState = CountingState.Attack;
                        await Task.Delay(1000);
                        break;

                    case CountingState.Attack:
                        announcer.AnnounceAsync("Attack", 10, 120);
                        countingState = CountingState.Defense;
                        await Task.Delay(1000);
                        break;

                    case CountingState.Defense:
                        announcer.AnnounceAsync("Defense", 10, 120);
                        countingState = CountingState.Six;
                        await Task.Delay(1000);
                        break;

                    case CountingState.None:
                    default:
                        break;
                }
            
            }
        }

        public void StopCountDown()
        {
            Interlocked.Increment(ref this.count);
        }
    }
}