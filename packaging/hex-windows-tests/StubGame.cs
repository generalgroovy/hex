using System;
using System.IO;
using System.Text;
using System.Threading;
internal static class StubGame
{
    private static void Main(string[] args)
    {
        string output = Environment.GetEnvironmentVariable("HEX_STUB_OUTPUT");
        if (!String.IsNullOrEmpty(output))
        {
            string[] encoded = Array.ConvertAll(args, delegate(string arg) { return Convert.ToBase64String(Encoding.UTF8.GetBytes(arg)); });
            File.WriteAllLines(output, encoded);
            File.WriteAllText(output + ".executable", System.Reflection.Assembly.GetExecutingAssembly().Location);
        }
        string delay = Environment.GetEnvironmentVariable("HEX_STUB_DELAY");
        if (!String.IsNullOrEmpty(delay)) Thread.Sleep(Int32.Parse(delay));
    }
}
