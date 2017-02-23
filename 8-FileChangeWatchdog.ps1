$folder = 'c:\FileCompareA'
$filter = '*.*'                             # <-- set this according to your requirements
#$dest = "c:\Uploadfiles"
$fsw = New-Object System.IO.FileSystemWatcher $folder, $filter -Property @{
 IncludeSubdirectories = $true;             # <-- set this according to your requirements
 NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite, DirectoryName'

}

#Remove registered ObjectEvent
Get-EventSubscriber -SourceIdentifier FinalFileCreated2 | Unregister-Event
Get-Event | Remove-Event


#register ObjectEvent
$onCreated = Register-ObjectEvent $fsw Created -SourceIdentifier FinalFileCreated2 -Action {
 $path = $Event.SourceEventArgs.FullPath
 $name = $Event.SourceEventArgs.Name
 $changeType = $Event.SourceEventArgs.ChangeType
 $timeStamp = $Event.TimeGenerated
 
 Write-Host "The file '$name' was $changeType at $timeStamp" -ForegroundColor Yellow

#Copy only the changed folder to c:\filecompareA
write-host "Copying all folders with changes made to them." -ForegroundColor Cyan
Copy-Item $Event.SourceEventArgs.FullPath -Destination C:\Uploadfiles -Verbose -Recurse -Force

 Start-Sleep -s 30


#add PSSnapin
$ver = $host | select version
if($Ver.version.major -gt 1) {$Host.Runspace.ThreadOptions = "ReuseThread"}
if(!(Get-PSSnapin Microsoft.SharePoint.PowerShell -ea 0))
{
Add-PSSnapin Microsoft.SharePoint.PowerShell
}


#create array from Uploadfiles folder to create the site collections

$arr2 = Get-ChildItem c:\Uploadfiles | 
       Where-Object {$_.PSIsContainer} | 
       Foreach-Object {$_.Name}

#Create Site Collections based on array names
write-host "Will now create site collections if they do not exist" -ForegroundColor Yellow
write-host "Please wait ..." -ForegroundColor Yellow

ForEach ($url in $arr2){

#Remove the site collection if it exists. 

#Remove-SPsite http://uxdesigns.dev.cox.com/sites/$url 
#Remove-SPcontentdatabase Wss_Content_Intranet_$url 

#Create new site collection
#If the site collections does not exist

Write-host "Creating content dabase for .." $url -ForegroundColor cyan
$template = Get-SPWebTemplate "STS#0"
New-SPContentDatabase -Name Wss_Content_Intranet_$url -webApplication http://uxdesigns.dev.cox.com 

Write-host "Creating site collection for .." $url -ForegroundColor cyan
New-SPSite -Url http://uxdesigns.dev.cox.com/sites/$url -OwnerAlias corp\dougwatt -Template $template
#New-SPUser -UserAlias 'corp\bschwar' -DisplayName 'Brendon Schwartz' -WebApplication #http://uxdesigns.dev.cox.com -SiteCOllectionAdmin

Write-host "The Prototypes library is being created for the site collection. " -ForegroundColor Cyan


$spWeb = Get-SPWeb -Identity http://uxdesigns.dev.cox.com/sites/$url
$listTemplate = [Microsoft.SharePoint.SPListTemplateType]::DocumentLibrary 
$spWeb.Lists.Add('Prototypes','This library is for prototypes only.',$listTemplate)

write-host $url "Site collection has been created!" -foregroundcolor "yellow"
write-host ""
write-host ""
write-host "The folders will now be uploaded to site collection ..." $url -ForegroundColor Yellow

write-host "Folders and files are being uploaded to site collection Prototypes library. Please wait ..." -ForegroundColor Cyan

##Unload folders and files to site collection Prototypes library
#Set Variables
##

$SiteURL = "http://uxdesigns.dev.cox.com/sites/$url"
$Directory = "C:\Uploadfiles"
write-host $siteurl "is the site collection URL." -Foregroundcolor yellow
write-host $Directory "is the location of the subfolders." -Foregroundcolor yellow

##
#Define Functions
##


##
#Start Script
##

#This process can generate several messages.  These are expected, but unsightly.  For this reason we set the ErrorActionPreference to "silentlycontinue".

#Assign the current ErrorActionPreference value to a variable, such that we can revert when the script completes
$DefaultErrorHandling = $ErrorActionPreference

#Set the ErrorActionPreference to "SilentlyContinue"
$ErrorActionPreference = "SilentlyContinue"

#Call the TrimDirectory function to remove any trailing slashes from the directory
#TrimDirectory $Directory

#Retrieve the SPSite based on the URL referenced above, assign this to a variable
$Site = Get-SPSite $SiteURL

#Set the SourceFolder variable to a subfolder within the location specified by the $Directory variable above
$arr3 = Get-ChildItem c:\Uploadfiles | 
       Where-Object {$_.PSIsContainer} | 
       Foreach-Object {$_.Name}
$SourceFolder = $arr3

Write-host "The Directory name is " $Directory -foregroundcolor white
Write-host "SourceFolder is " $SourceFolder -foregroundcolor white

##THE CODE WORKS TO THIS POINT

Function TrimDirectory ($Directory) 
{ 
    #If the loging direcotry ends with a slash, remove the trailing slash 
    if($Directory.EndsWith("\")) 
    { 
        #Remove the last character, which will be a slash, from the specified directory 
        Set-Variable -Name Directory -Value ($Directory.Substring(0, ($Directory.Length -1))) -Scope Script 
    } 
} 


Function ImportFiles($SourceFolder, $Splist)
{
    #Get The root folder, assign it to a variable, as we'll be referring to this a few times
    $RootFolder = Get-Item $SourceFolder
    Write-host $RootFolder "is the RootFolder test" -Foregroundcolor green
    Write-host $SourceFolder "is a SourceFolder test" -Foregroundcolor green
    Write-host $Directory "is the directory" -Foregroundcolor green
    Write-host $SourceFolder "is the SourceFolder" -Foregroundcolor green
    Write-host $DestinationLibrary "is the DestinationLibrary" -Foregroundcolor green
    
    #Get a recursive list of all folders beneath the root folder
    $AllFolders = Get-ChildItem -Recurse $RootFolder | ? {!$_.psIsContainer -eq $False} | foreach -Process {$_.FullName}

        
    #Get a list of all files in the root folder.  These files are uploaded slightly differently than files which are not in the root of a library
    $AllFiles = Get-ChildItem -Recurse $RootFolder | ? {$_.psIsContainer -eq $False} | foreach -Process {$_.FullName}
    
    
    #Loop through all files in the root folder and upload them to SharePoint
    foreach($File in $AllFiles)
    {
        #Get the file stream of each file, assign it to a variable.  This is needed in order to duplicate the file in SharePoint
        $Stream = (Get-Item $File).openread()
        
        #Create a new file using the file name and stream from the source file, overwrite the file if it exists
        $newfile = $MasterPageGallery.RootFolder.Files.Add(((get-item $File).name), $Stream, $True)
        
        #Check in the file
        $NewFile.CheckIn($True)
        
        #Publish the file
        $NewFile.Publish($True)
        
        #Approve the file
        $NewFile.Approve($True)
        
        #Commit these updates
        $NewFile.Update()
    }
    
    #Loop through all folders beneath the root folder, Create the folder if it doesn't exist, and populate the folders with files from the source
    foreach ($Folder in $AllFolders)
    {
        #Ensure the ParentFolderPath variable does not exist, so that we're appending path chunks to a clean variable
        if($ParentFolderPath)
        {
            #This removes the variable
            Remove-Variable ParentFolderPath
        }
        
        #Return the current folder to a variable
        $CurrentFolder = Get-Item $Folder
        
        #Determine the folder relative path by removing the source folder path from the string
        $FolderRelativePath = (Get-Item $CurrentFolder).FullName.Substring($SourceFolder.length)
        
        $i = 0
         
        #Split the folder path into chunks based on the "\" character.  This determines hierarchy
        $FolderPathChunks = $FolderRelativePath.Split("\")
        
        #Loop through the folder path in order to determine what the path of the parent folder is.  This allows us to determine where to create the folder.
        while($I -lt ($FolderPathChunks.count -1))
        {
            $ParentFolderPath = ("$ParentFolderPath/" + $FolderPathChunks[$I])
            $I++
        }
        
        #Determine where to put the files based on who the parent is.
        if($ParentFolderPath -eq "/")
        {
            #If the parent of the folder is the root of the library, we'll create the folder in the root of the library
            $FolderURL = $SiteURL + "/" + ($SPList.RootFolder.url)
        }
        else
        {
            #If the parent of the folder is a subfolder within the library, we'll create the folder in that child folder
            $FolderURL = $SiteURL + "/" + ($SPList.RootFolder.url) + ($ParentFolderPath.Substring(1))
            
        }
        
        #Create a new folder in a location which is relative to the location of the folder within the source dirctory
        $SiteFolder = $SPList.Folders.Add($FolderURL, [Microsoft.SharePoint.SPFileSystemObjectType]::Folder, (Get-Item $CurrentFolder).Name)
        
        #Commit this change so we have an object to "approve"
        $SiteFolder.Update()
        
        #Set the folder approval status to "0", approved
        $SiteFolder["_ModerationStatus"] = 0
        
        #Commit this change so we can create objects in the folder
        $SiteFolder.Update()

        #Get a list of the files in the source folder on the file system
        $FilesInFolder = Get-ChildItem $CurrentFolder | ? {$_.PsIsContainer -eq $False}
        
        #Loop through all of the files in the folder and upload these files to SharePoint
        foreach($File in $FilesInFolder)
        {
            #Get the file stream of each file, assign it to a variable.  This is needed in order to duplicate the file in SharePoint
            $Stream = (Get-Item $File.fullname).openread()

            #Create a new file using the file name and stream from the source file, overwrite the file if it exists
            $NewFile = $SiteFolder.Folder.Files.Add($File.Name, $Stream, $True)

            #Chewck in the file
            $NewFile.CheckIn($True)

            #Publish the file
            $NewFile.Publish($True)

            #Approve the file
            $NewFile.Approve($True)

            #Commit these changes
            $NewFile.Update()
            
        }
        
    }

}

}


#Set the ErrorActionPreference back to the value it was before the execution of this script
$ErrorActionPreference = $DefaultErrorHandling

#Set the Destination Library by using the title of the destination library which already exists in the environment
$DestinationLibrary = $Site.RootWeb.Lists | ? {$_.title -eq "Prototypes"}
Write-host "Prototypes is the name of the library" -Foregroundcolor green

#Call the ImportFiles function, which will take files from the source folder and duplicate them into the destination library
ImportFiles ($Directory +"\"+ $SourceFolder) $DestinationLibrary

#Return a message to the user that the file copy completed
Write-Host "File Copy Completed"
Write-host ""
Write-host ""


}

    
