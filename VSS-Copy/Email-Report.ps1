$CallEmailReport = {

if ($EmailReport)
{

    $EmailAddress = $EmailAddress.Replace(' ','').split(',')

    $emailMessage = " "

    $EmailAttachment = $EmailAttachment.Replace(' ','').Split(',')


    Write-Log -Level Debug -Message "Email Subject: $emailSubject" -LogLevel $LogVerbosity -Path $LogPath
    Write-Log -Level Debug -Message "Email Addresses: $EmailAddress" -LogLevel $LogVerbosity -Path $LogPath
   


    Try
    {

        #$SmtpServer = ""
        #$EmailAddress = $EmailReport
        #$EmailFromAddress = "noreply@domain.local"
        

        $emailCredentials = New-Object System.Management.Automation.PSCredential("anonymous","anonymous" | ConvertTo-SecureString -AsPlainText -Force)


        if($EmailAddress -ne $null -and $SmtpServer -ne $null)
        {

            if($EmailAttachment -ne $null)
            {
                Send-MailMessage -SmtpServer $SmtpServer `
                -From $EmailFromAddress `
                -To $EmailAddress `
                -Subject $emailSubject `
                -Body $emailMessage `
                -Credential $emailCredentials `
                -Attachments $EmailAttachment
            }
            Else
            {
                Send-MailMessage -SmtpServer $SmtpServer `
                -From $EmailFromAddress `
                -To $EmailAddress `
                -Subject $emailSubject `
                -Body $emailMessage `
                -Credential $emailCredentials `

            }
        }
    }
    Catch
    {

        Write-Log -Level Warn -Message "Error Sending email" -LogLevel $LogVerbosity -Path $LogPath
        Write-Log -Level Warn -Message ($Error[0] | Out-String) -LogLevel $LogVerbosity -Path $LogPath
    }
}


Exit


}
