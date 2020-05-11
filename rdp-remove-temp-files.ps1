
Get-ChildItem C:\Windows\Temp -Recurse -Force | Remove-Item -Recurse -Force

$chromeFolderList = @("Cache", "File System", "Service Worker", "GPUCache", "Local Storage")



$users = Get-ChildItem C:\users
ForEach($user in $users)
{

    Get-ChildItem "C:\Users\$user\AppData\Local\Temp\" -Recurse -Force | Remove-Item -Force -Recurse

    Get-ChildItem "C:\Users\$user\AppData\Local\Microsoft\Windows\INetCache\" -Recurse -Force | Remove-Item -Force -Recurse


    ForEach($folder in $chromeFolderList)
    {

       Get-ChildItem "C:\Users\$user\AppData\Local\Google\Chrome\User Data\Default\$folder" -Recurse -Force | Remove-Item -Recurse -Force

    }








    $firefoxProfiles = Get-ChildItem "C:\Users\$user\AppData\Local\Mozilla\Firefox\Profiles\"

    ForEach($firefoxProfile in $firefoxProfiles)
    {
        Get-ChildItem "C:\Users\$user\AppData\Local\Mozilla\Firefox\Profiles\$firefoxProfile\cache2\entries" -Recurse -Force | Remove-Item -Recurse -Force

    }






}