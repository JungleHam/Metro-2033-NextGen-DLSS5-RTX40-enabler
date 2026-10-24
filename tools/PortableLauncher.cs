// Single executable portable Metro NR manager. All scripts and proxy are embedded.
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

internal static class MetroPortable
{
    [STAThread]
    private static int Main()
    {
        string scratch = Path.Combine(Path.GetTempPath(), "MetroNR-Portable-" + Guid.NewGuid().ToString("N"));
        try
        {
            Directory.CreateDirectory(scratch);
            string payload = Path.Combine(scratch, "payload.zip");
            using (Stream data = Assembly.GetExecutingAssembly().GetManifestResourceStream("MetroNR.Payload.zip"))
            {
                if (data == null) throw new InvalidOperationException("Installer payload is missing.");
                using (FileStream output = File.Create(payload)) data.CopyTo(output);
            }
            ZipFile.ExtractToDirectory(payload, scratch);
            File.Delete(payload);
            string manager = Path.Combine(scratch, "MetroNR-Manager.ps1");
            if (!File.Exists(manager) || !File.Exists(Path.Combine(scratch, @"build\dinput8.dll")))
                throw new InvalidOperationException("The installer package is incomplete.");
            string powershell = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                @"System32\WindowsPowerShell\v1.0\powershell.exe");
            if (!File.Exists(powershell)) throw new FileNotFoundException("Windows PowerShell not found.", powershell);
            ProcessStartInfo info = new ProcessStartInfo();
            info.FileName = powershell;
            info.Arguments = "-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + manager + "\"";
            info.WorkingDirectory = scratch;
            info.CreateNoWindow = true;
            info.WindowStyle = ProcessWindowStyle.Hidden;
            info.UseShellExecute = false;
            using (Process child = Process.Start(info))
            {
                if (child == null) throw new InvalidOperationException("Could not open the installer window.");
                child.WaitForExit();
                if (child.ExitCode != 0) throw new InvalidOperationException("Installer window stopped unexpectedly (code " + child.ExitCode + ").");
            }
            return 0;
        }
        catch (Exception exception)
        {
            string log = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                @"Metro-NR-RTX40\Logs\Portable-launcher.log");
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(log));
                File.AppendAllText(log, DateTime.Now.ToString("o") + " " + exception + Environment.NewLine, Encoding.UTF8);
            }
            catch { }
            MessageBox.Show("The Metro NR installer could not start:\n\n" + exception.Message +
                "\n\nMore details: " + log, "Metro NR Portable Installer", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        finally
        {
            // Backups, user preferences and diagnostics are outside this temporary directory.
            try { if (Directory.Exists(scratch)) Directory.Delete(scratch, true); } catch { }
        }
    }
}
