namespace CountDown
{
    using System.Threading.Tasks;

    public interface IAnnouncer
    {
        Task AnnounceAsync(string text);

        Task AnnounceAsync(string text, int pitch, int ratePercent);

        Task AnnounceAsync(string text, int pitch, int ratePercent, bool forced);
    }
}
