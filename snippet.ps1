#Author: snair@vmware.com

param(
[parameter(Mandatory = $true)]
$server_ip
<# [parameter(Mandatory = $true)]
$User,
[parameter(Mandatory = $true)]
$Password,
[parameter(Mandatory = $true)]
$cluster #>
 )


function chkslpd($h){
    $vm_host = Get-VMHost $h
    $power_status = $vm_host.ExtensionData.Runtime.PowerState
    if($power_status -ieq "PoweredOff")
    {
        Write-Output "Host is poweroff"
        return
    }
    $esxcli = Get-EsxCli -VMHost $vm_host -V2  
	$value = Get-VMHost -name $vm_host | Get-VMHostService | where {$_.key -eq 'slpd'} | Stop-VMHostService -Confirm:$false
		if($value){
            Write-Output "`n[$vm_host]Disabling SLP Service"
            }else{
                Write-Output "Unable to disable the slp service on $vm_host "
		        disconnect
                EXIT
            }
	$value1 = Get-VMHostFirewallException -VMHost $vm_host | where {$_.Name.StartsWith('CIM SLP')} | Set-VMHostFirewallException -Enabled $false
	if($value1){
            Write-Output "`n[$vm_host]Disabling Firewall Exception RuleSet for CIM SLP"
            }else{
                Write-Output "Unable to disable the Firewall Exception RuleSetfor CIM SLP on $vm_host"
		        disconnect
                EXIT
            }
	$value2 = Get-VMHost -name $vm_host | Get-VmHostService | Where-Object {$_.key -eq 'slpd'} | Set-VMHostService -policy 'off'
	if($value2){
            Write-Output "`n[$vm_host]Updating SLP Service Policy to make this change persistent across reboots"
            }else{
                Write-Output "Unable to update slpd service on $vm_host"
		        disconnect
                EXIT
            }
	$valuechk = Get-VMHostService -VMHost $vm_host -Refresh | Where-Object {$_.key -eq 'slpd'} | select -ExpandProperty Running
	Write-Output "`n[$vm_host]SLP Service Running Status is set to $valuechk now"	
	$value1chk = Get-VMHostFirewallException -VMHost $vm_host | where {$_.Name.StartsWith('CIM SLP')} | select -ExpandProperty ServiceRunning
	Write-Output "`n[$vm_host]Firewall Exception RuleSetfor CIM SLP is set to $value1chk now"	
	$value2chk = Get-VMHost -name $vm_host | Get-VmHostService | Where-Object {$_.key -eq 'slpd'} | select -ExpandProperty Policy
	Write-Output "`n[$vm_host]SLP Service Policy is turned $value2chk"	
	
}

function getCluster{
    $allcluster = Get-Cluster -Server $server_ip
    if ($allcluster){
        
        if ($cluster){
            $found = $False
            foreach ($cls in $allcluster){
                #If cluster passed as parameter 
                if ( $cluster -eq $cls){
                    $found = $True
                    $host_name = Get-Cluster $cls | Get-VMHost | Where-Object {$_.ConnectionState -eq 'Connected'}
                    Write-Output "`n========================================================"
                    Write-Output "On Cluster: $cls"
                    Write-Output "========================================================"
                    
                    foreach($h in $host_name){
                        chkslpd($h)
                    }
                }
            }if (!$found){
                Write-Output "$cluster not found"
                disconnect
                EXIT
            }
        
        }else {
            
            foreach ($cls in $allcluster){
                $host_name = Get-Cluster $cls | Get-VMHost | Where-Object {$_.ConnectionState -eq 'Connected'} -ErrorAction SilentlyContinue
                Write-Output "`n========================================================"
                Write-Output "On Cluster: $cls"
                Write-Output "========================================================"
                foreach($h in $host_name){
                    chkslpd($h)
                }
            }
        }
    }else { Write-Output "No Cluster in inventory" }
}

function Modify_Esx(){
            Write-Output "Using ESX $server_ip" 
            Write-Output "========================================================"
	        $h2 = Get-VMHost -Server $server_ip
	        chkslpd($h2)   
        }
       
function disconnect(){
	 Disconnect-VIServer -Server $Server_ip -Confirm:$False
    if($?){
        Write-Output "`n========================================================"
        Write-Output "Sucessfully Disconnect-VIServer $server_ip" 
        Write-Output "========================================================"
    }else{
        Write-Output "`n========================================================"
        Write-Output "Failed to Disconnect-VIServer $server_ip" 
        Write-Output "========================================================"
    }
}


Write-Output "`n========================================================"
Write-Output  "Attempting to connect $server_ip"
$viConnection = if (Connect-VIServer -Server $server_ip -User $User -Password $Passwd -ErrorAction SilentlyContinue) { $TRUE } else { $FALSE }

if ($viConnection) 
{ 
	Write-Output "ConnectServer: Sucessfully connected to $server_ip" 
    Write-Output "========================================================"
    $check=Get-Cluster -Server $server_ip
    if(!$check){
        Modify_Esx
    }else{
    getCluster
    }
   disconnect
    
}
else { 
    Write-Output "Error: connection to $server_ip failed"
}





   
    





    

    
    
 