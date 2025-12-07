param(
   [string]$Disk,
   [string]$FileSystem = "NTFS",
   [string]$VolumeName = "USB",
   [string]$EFILetter = "E",
   [string]$PrimaryLetter = "F",
   [switch]$GPT,
   [switch]$MBR,
   [string]$Action
)

function Format-DiskWithEFI {
   param([string]$DiskNumber)
   
   $script = @"
select disk $DiskNumber
clean
convert gpt
create partition efi size=100
create partition primary
format fs=fat32 quick label=WEFI
assign letter=$EFILetter
select partition 2
format fs=$FileSystem quick label=$VolumeName
assign letter=$PrimaryLetter
"@
   
   $script | diskpart
}

function Format-LargeFileSystem {
   param([string]$DiskNumber)
   
   $script = @"
select disk $DiskNumber
clean
$(if ($MBR) { "convert mbr" } else { "convert gpt" })
create partition primary size=100
format fs=fat32 quick label=WEFI
assign letter=$EFILetter
create partition primary
format fs=$FileSystem quick label=$VolumeName
assign letter=$PrimaryLetter
"@
   
   $script | diskpart
}

if ($Action -eq "diskWithEFI") {
   Format-DiskWithEFI -DiskNumber $Disk
}
elseif ($Action -eq "largeFileSystem") {
   Format-LargeFileSystem -DiskNumber $Disk
}
