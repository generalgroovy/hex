using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Reflection;
using System.Windows.Forms;
internal static class LauncherPreview
{
    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Length != 3) return 2;
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Assembly assembly = Assembly.LoadFile(System.IO.Path.GetFullPath(args[0]));
        Type window = assembly.GetType("Hex.Bootstrap.Program+LaunchWindow", true);
        using (Form form = (Form)Activator.CreateInstance(window, new object[] { args[1] }))
        {
            if (form.Text != "H.E.X.") throw new InvalidOperationException("Incorrect launcher window branding.");
            form.ShowInTaskbar = false;
            form.StartPosition = FormStartPosition.Manual;
            form.Location = new Point(-32000, -32000);
            form.Show();
            Application.DoEvents();
            using (Bitmap bitmap = new Bitmap(form.Width, form.Height))
            {
                form.DrawToBitmap(bitmap, new Rectangle(0, 0, bitmap.Width, bitmap.Height));
                bitmap.Save(args[2], ImageFormat.Png);
            }
        }
        return 0;
    }
}
