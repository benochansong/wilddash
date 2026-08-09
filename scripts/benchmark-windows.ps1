param(
    [Parameter(Mandatory=$true)]
    [string]$GodotPath,
    [string]$ProjectPath = (Join-Path $PSScriptRoot "..\godot"),
    [string]$OutputCsv = (Join-Path $PSScriptRoot "..\godot\benchmark\windows-benchmark.csv"),
    [int[]]$RacerCounts = @(10, 25, 50)
)

$ErrorActionPreference = "Stop"
$logicalCpuCount = [Environment]::ProcessorCount
$rows = @()

function Parse-PerfLine([string]$line) {
    $result = @{}
    foreach ($token in ($line -split ' ')) {
        if ($token -notmatch '=') { continue }
        $parts = $token -split '=', 2
        $result[$parts[0]] = $parts[1]
    }
    return $result
}

foreach ($optimized in @($false, $true)) {
    $profile = if ($optimized) { "optimized" } else { "baseline" }
    foreach ($racers in $RacerCounts) {
        $env:WILDDASH_RACER_COUNT = "$racers"
        $env:WILDDASH_OPTIMIZED = if ($optimized) { "1" } else { "0" }

        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = (Resolve-Path $GodotPath)
        $psi.WorkingDirectory = (Resolve-Path $ProjectPath)
        $psi.Arguments = "--path `"$ProjectPath`" res://benchmark/race_benchmark.tscn"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $false

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $psi
        [void]$process.Start()
        $pidValue = $process.Id
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        $cpuSamples = @()
        $gpuSamples = @()
        $workingSetPeakMb = 0.0
        $lastCpu = $process.TotalProcessorTime.TotalSeconds
        $lastWall = [DateTime]::UtcNow

        while (-not $process.HasExited) {
            Start-Sleep -Milliseconds 500
            if ($process.HasExited) { break }
            $process.Refresh()
            $now = [DateTime]::UtcNow
            $cpuNow = $process.TotalProcessorTime.TotalSeconds
            $wallSeconds = [Math]::Max(0.001, ($now - $lastWall).TotalSeconds)
            $cpuPct = (($cpuNow - $lastCpu) / $wallSeconds / $logicalCpuCount) * 100.0
            $cpuSamples += [Math]::Max(0.0, $cpuPct)
            $workingSetPeakMb = [Math]::Max($workingSetPeakMb, $process.WorkingSet64 / 1MB)
            $lastCpu = $cpuNow
            $lastWall = $now

            try {
                $counter = Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction Stop
                $gpu3d = ($counter.CounterSamples | Where-Object {
                    $_.InstanceName -match "pid_${pidValue}_" -and $_.InstanceName -match 'engtype_3D'
                } | Measure-Object CookedValue -Sum).Sum
                if ($null -ne $gpu3d) { $gpuSamples += [double]$gpu3d }
            } catch {
                # GPU Engine counters are not available on every Windows/driver combination.
            }
        }

        $process.WaitForExit()
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        Write-Host $stdout
        if ($stderr) { Write-Warning $stderr }
        if ($process.ExitCode -ne 0) { throw "Godot benchmark failed: profile=$profile racers=$racers exit=$($process.ExitCode)" }

        $perfLine = ($stdout -split "`r?`n" | Where-Object { $_ -like 'PERF_RESULT *' } | Select-Object -Last 1)
        if (-not $perfLine) { throw "PERF_RESULT missing: profile=$profile racers=$racers" }
        $perf = Parse-PerfLine $perfLine

        $rows += [pscustomobject]@{
            profile = $profile
            racers = $racers
            fps_avg = [double]$perf.fps_avg
            process_ms = [double]$perf.process_ms
            physics_ms = [double]$perf.physics_ms
            engine_cpu_budget_pct = [double]$perf.engine_cpu_budget_pct
            os_cpu_pct_avg = if ($cpuSamples.Count) { ($cpuSamples | Measure-Object -Average).Average } else { 0 }
            gpu_3d_pct_avg = if ($gpuSamples.Count) { ($gpuSamples | Measure-Object -Average).Average } else { -1 }
            ai_ms_per_frame = [double]$perf.ai_ms_per_frame
            ai_usec_per_call = [double]$perf.ai_usec_per_call
            ai_brain_updates = [int]$perf.ai_brain_updates
            ai_raycast_calls = [int]$perf.ai_raycast_calls
            draw_calls_avg = [double]$perf.draw_calls_avg
            primitives_avg = [double]$perf.primitives_avg
            physics_pairs_avg = [double]$perf.physics_pairs_avg
            godot_memory_mb_peak = [double]$perf.memory_mb_peak
            working_set_mb_peak = [Math]::Round($workingSetPeakMb, 2)
            video_memory_mb_peak = [double]$perf.video_memory_mb_peak
        }
    }
}

$rows | Export-Csv -NoTypeInformation -Encoding UTF8 $OutputCsv
$rows | Format-Table -AutoSize
Write-Host "Windows benchmark written to $OutputCsv"
