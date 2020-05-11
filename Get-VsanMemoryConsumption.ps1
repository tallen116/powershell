


$vCenterServer = "vcenter.local"
$vSanCluster = "vsan-cluster"
$credentials = Get-Credential

Try {
    #Disconnect-VIServer * -Force | Out-Null
    Connect-VIServer -Server $vCenterServer -Credential $credentials

}
Catch {
    Write-host "Can't connect to vCenter"
    Exit
}

$vSanHosts = Get-Cluster -Name $vSanCluster -Server $vCenterServer | Get-VMHost

$vSanMemoryOverhead = [System.Collections.ArrayList]@()


# Constants for VSAN
$VSAN_BASE_CONSUMPTION = 5246
$VSAN_DISKGROUP_BASE_CONSUMPTION = 636
$VSAN_SSD_MEM_OVERHEAD_PER_GB_HYBRID = 8
$VSAN_SSD_MEM_OVERHEAD_PER_GB_FLASH = 14
$VSAN_CAPACITY_DISK_BASE_CONSUMPTION = 70

# Base formula is
# ------------------------------
# BaseConsumption + 
# (NumDiskGroups * ( DiskGroupBaseConsumption + (SSDMemOverheadPerGB * SSDSize ))) +
# (NumCapacityDisks * CapacityDiskBaseConsumption)

ForEach($vSanHost in $vSanHosts) {
    Write-Host $vSanHost
    $vsanDisks = $vSanHost | Get-VsanDisk

    $hostVsanNumDiskGroups = $vSanHost | Get-VsanDiskGroup
    $hostVsanNumDiskGroupCount = ($hostVsanNumDiskGroups).count
    $hostVsanNumCapacityDisks = ( $vSanHost | Get-VsanDisk | Where-object {$_.IsCacheDisk -eq $false}).count
    $hostDiskGroupAllFlash = $true

    Write-host $hostVsanNumDiskGroupCount
    Write-Host $hostVsanNumCapacityDisks

    foreach($hostVsanNumDiskGroup in $hostVsanNumDiskGroups){
        $hostDiskGroupAllFlash = $hostDiskGroupAllFlash -and ($hostVsanNumDiskGroup.DiskGroupType -eq "AllFlash")
    }

    Write-Host $hostDiskGroupAllFlash

    $hostVsanSSDSize = 0
    ForEach($vsanDisk in ($vsanDisks | Where-Object {$_.IsCacheDisk -eq $true} | Where-Object {$_.IsSsd -eq $true})) {
        
        $tempDiskSize = ($vsanDisk.ExtensionData.Capacity.BlockSize * $vsanDisk.ExtensionData.Capacity.Block) / (1024 * 1024 * 1024)
        if ($hostVsanSSDSize -lt $tempDiskSize) {
            $hostVsanSSDSize = $tempDiskSize
        }
    }
    Write-host $hostVsanSSDSize

    # 
    
    if (($hostDiskGroupAllFlash) -and ($hostVsanSSDSize -gt 600)) {
        $hostVsanSSDSize = 600
    }

    Write-host $hostVsanSSDSize


    if ($hostDiskGroupAllFlash) {
        $VSAN_SSD_MEM_OVERHEAD_PER_GB = $VSAN_SSD_MEM_OVERHEAD_PER_GB_FLASH
    }
    else {
        $VSAN_SSD_MEM_OVERHEAD_PER_GB = $VSAN_SSD_MEM_OVERHEAD_PER_GB_HYBRID
    }

    Write-Host $VSAN_SSD_MEM_OVERHEAD_PER_GB
    
    $hostMemoryTotal = $VSAN_BASE_CONSUMPTION + ( $hostVsanNumDiskGroupCount * ( $VSAN_DISKGROUP_BASE_CONSUMPTION + ( $VSAN_SSD_MEM_OVERHEAD_PER_GB * $hostVsanSSDSize ) ) ) + ( $hostVsanNumCapacityDisks * $VSAN_CAPACITY_DISK_BASE_CONSUMPTION)
    Write-Host $hostMemoryTotal
}
