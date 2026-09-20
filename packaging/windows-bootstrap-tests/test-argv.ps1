param([Parameter(Mandatory = $true)][string]$Installer)
$ErrorActionPreference = 'Stop'
# Called only after this exact installer has passed ordinary native execution.
# Invoking the private pure formatter does not run Main or modify an install.
if (-not ('FluxBootstrapArgvProbe' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class FluxBootstrapArgvProbe {
    [DllImport("shell32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    private static extern IntPtr CommandLineToArgvW(string command, out int count);
    [DllImport("kernel32.dll")] private static extern IntPtr LocalFree(IntPtr memory);
    public static string[] Parse(string command) {
        int count; IntPtr memory = CommandLineToArgvW("probe.exe " + command, out count);
        if (memory == IntPtr.Zero) throw new InvalidOperationException("Windows argument parser failed.");
        try {
            string[] result = new string[count - 1];
            for (int i = 1; i < count; i++) result[i - 1] = Marshal.PtrToStringUni(Marshal.ReadIntPtr(memory, i * IntPtr.Size));
            return result;
        } finally { LocalFree(memory); }
    }
}
'@
}
$assembly = [Reflection.Assembly]::LoadFile([IO.Path]::GetFullPath($Installer))
$type = $assembly.GetType('Flux.Bootstrap.Program', $true)
$method = $type.GetMethod('JoinArguments', [Reflection.BindingFlags]'Static, NonPublic')
if ($null -eq $method) { throw 'Installer has no expected private argument formatter.' }
$vectors = @(
    [string[]]@('', 'two words', 'quote"inside', 'C:\ending path\', 'one\"two', '--literal=value'),
    [string[]]@('"', '\', '\\', '\\"', "tab`tinside", ('unicode-' + [char]0x03a9)),
    [string[]]@('--headless', '--log-file', 'C:\safe test\game boot.log', '--', '--tick-rate=120')
)
$assertions = 0
foreach ($vector in $vectors) {
    $arguments = New-Object object[] 1
    $arguments[0] = $vector
    $joined = [string]$method.Invoke($null, $arguments)
    $parsed = [FluxBootstrapArgvProbe]::Parse($joined)
    if ($parsed.Count -ne $vector.Count) { throw 'Windows argv count changed.' }
    $assertions++
    for ($i = 0; $i -lt $vector.Count; $i++) {
        if ($parsed[$i] -cne $vector[$i]) { throw "Windows argv changed value at $i." }
        $assertions++
    }
}
Write-Output "PASS: $assertions actual Windows CommandLineToArgvW / embedded launcher formatter assertions."
