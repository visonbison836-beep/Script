$folder = "C:\Users\HP\AppData\Local\Microsoft\Edge\User Data\Default\Network"
$K = 150000
$threads = 8

New-Item -ItemType Directory -Path $folder -Force | Out-Null

Write-Host "Avvio: $K creazioni + $K eliminazioni"
Write-Host "Worker paralleli: $threads"

$start = Get-Date

$runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $threads)
$runspacePool.Open()

$jobs = @()

$scriptBlock = {
    param($folder, $startIndex, $endIndex)

    for ($i = $startIndex; $i -le $endIndex; $i++) {

        $name = "$(New-Guid).tmp"
        $path = Join-Path $folder $name

        try {
            [System.IO.File]::WriteAllBytes(
                $path,
                [byte[]](65)
            )

            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
        catch {
            # Ignora eventuali errori
        }
    }
}

$chunkSize = [Math]::Ceiling($K / $threads)

for ($t = 0; $t -lt $threads; $t++) {

    $startIndex = ($t * $chunkSize) + 1
    $endIndex = [Math]::Min(($t + 1) * $chunkSize, $K)

    if ($startIndex -gt $K) {
        break
    }

    $powershell = [PowerShell]::Create()
    $powershell.RunspacePool = $runspacePool

    [void]$powershell.AddScript($scriptBlock)
    [void]$powershell.AddArgument($folder)
    [void]$powershell.AddArgument($startIndex)
    [void]$powershell.AddArgument($endIndex)

    $handle = $powershell.BeginInvoke()

    $jobs += [PSCustomObject]@{
        PowerShell = $powershell
        Handle     = $handle
    }
}

Write-Host "Worker avviati."

foreach ($job in $jobs) {
    $job.PowerShell.EndInvoke($job.Handle)
    $job.PowerShell.Dispose()
}

$runspacePool.Close()
$runspacePool.Dispose()

$elapsed = (Get-Date) - $start

Write-Host ""
Write-Host "Completato."
Write-Host "Creazioni:    $K"
Write-Host "Eliminazioni: $K"
Write-Host "Worker:       $threads"
Write-Host "Tempo:        $($elapsed.ToString('hh\:mm\:ss'))"
