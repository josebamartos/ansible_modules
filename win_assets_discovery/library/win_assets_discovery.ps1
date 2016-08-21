#!powershell
# <license>

# WANT_JSON
# POWERSHELL_COMMON

[Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" ) > Out-Null

$module = New-Object psobject @{
    changed = $false
};


#########
# Lists #
#########

$jboss_classifications = @{
    'JBoss_4_0_0'           = 'AS 4';
    'JBoss_4_0_1_SP1'       = 'AS 4';
    'JBoss_4_0_2'           = 'AS 4';
    'JBoss_4_0_3_SP1'       = 'AS 4';
    'JBoss_4_0_4_GA'        = 'AS 4';
    'Branch_4_0'            = 'AS 4';
    'JBoss_4_2_0_GA'        = 'AS 4';
    'JBoss_4_2_1_GA'        = 'AS 4';
    'JBoss_4_2_2_GA'        = 'AS 4';
    'JBoss_4_2_3_GA'        = 'AS 4';
    'JBoss_5_0_0_GA'        = 'AS 5';
    'JBoss_5_0_1_GA'        = 'AS 5';
    'JBoss_5_1_0_GA'        = 'AS 5';
    'JBoss_6.0.0.Final'     = 'AS 6';
    'JBoss_6.1.0.Final'     = 'AS 6';
    '1.0.1.GA'              = 'AS 7';
    '1.0.2.GA'              = 'AS 7';
    '1.1.1.GA'              = 'AS 7';
    '1.2.0.CR1'             = 'AS 7';
    '1.2.0.Final'           = 'WildFly 8';
    '1.2.2.Final'           = 'WildFly 8';
    '1.2.4.Final'           = 'WildFly 8';
    '1.3.0.Beta3'           = 'WildFly 8';
    '1.3.0.Final'           = 'WildFly 8';
    '1.3.3.Final'           = 'WildFly 8';
    '1.3.4.Final'           = 'WildFly 9';
    '1.4.2.Final'           = 'WildFly 9';
#    '1.4.3.Final'           = 'WildFly 9';
    '1.4.3.Final'           = 'WildFly 10';
    '1.4.4.Final'           = 'WildFly 10';
    'JBPAPP_4_2_0_GA'       = 'EAP 4.2';
    'JBPAPP_4_2_0_GA_C'     = 'EAP 4.2';
    'JBPAPP_4_3_0_GA'       = 'EAP 4.3';
    'JBPAPP_4_3_0_GA_C'     = 'EAP 4.3';
    'JBPAPP_5_0_0_GA'       = 'EAP 5.0.0';
    'JBPAPP_5_0_1'          = 'EAP 5.0.1';
    'JBPAPP_5_1_0'          = 'EAP 5.1.0';
    'JBPAPP_5_1_1'          = 'EAP 5.1.1';
    'JBPAPP_5_1_2'          = 'EAP 5.1.2';
    'JBPAPP_5_2_0'          = 'EAP 5.2.0';
    '1.1.2.GA-redhat-1'     = 'EAP 6.0.0';
    '1.1.3.GA-redhat-1'     = 'EAP 6.0.1';
    '1.2.0.Final-redhat-1'  = 'EAP 6.1.0';
    '1.2.2.Final-redhat-1'  = 'EAP 6.1.1';
    '1.3.0.Final-redhat-2'  = 'EAP 6.2';
#    '1.3.3.Final-redhat-1'  = 'EAP 6.2';
    '1.3.3.Final-redhat-1'  = 'EAP 6.3';
    '1.3.4.Final-redhat-1'  = 'EAP 6.3';
    '1.3.5.Final-redhat-1'  = 'EAP 6.3';
    '1.3.6.Final-redhat-1'  = 'EAP 6.4';
    '1.3.7.Final-redhat-1'  = 'EAP 6.4'
}


#############
# Variables #
#############

$assets = @()
$search_root = @(Get-WmiObject Win32_Volume -Filter "DriveType='3'"|select -expand driveletter)


#############
# Functions #
#############

function extract_file ($archive, $filename, $output){
    $basename = $filename.split('/')[-1]

    $zip_stream = [System.IO.Compression.ZipFile]::OpenRead($archive)
    $file_stream = New-Object IO.FileStream ("$output\$basename") ,'Append','Write','Read'
    
    $content = $zip_stream.GetEntry($filename).Open()
    $content.CopyTo($file_stream)

    $content.Close()
    $zip_stream.Dispose()
    $file_stream.Close()
}

function get_cores(){
    $cores = @(gwmi -Class Win32_ComputerSystemProcessor).Count
    return $cores
}

function get_hostname(){
    $hostname = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain
    return $hostname
}

function get_value($file, $regexp){
    $value = ""
    $text = Get-Content $file

    foreach ($line in $text){
        if ([regex]::Match($line, $regexp).Success){
            $value = [regex]::Match($line, $regexp).Groups[1].toString()
        }
    }
    return $value
}

function get_zipped_file_value ($archive, $filename, $regexp){
    $value = ""
    $zip_stream = [System.IO.Compression.ZipFile]::OpenRead($archive)
    $mem_stream = new-object IO.MemoryStream

    $content = $zip_stream.GetEntry($filename).Open()
    $content.CopyTo($mem_stream)
    $zip_stream.Dispose()
    $content.Close()

    $mem_stream.Position = 0
    $reader = New-Object IO.StreamReader($mem_stream)
    $text = ($reader.ReadToEnd() -split '[\r\n]') |? {$_} 

    $reader.Close()
    $mem_stream.Close()

    foreach ($line in $text){
        if ([regex]::Match($line, $regexp).Success){
            $value = [regex]::Match($line, $regexp).Groups[1].toString()
        }
    }

    return $value
}


function jboss_pretty_version($version){
    if ($jboss_classifications.ContainsKey($version)){
        $pretty_version = $jboss_classifications[$version]
    } else {
        $pretty_version = "Unknown-JBoss-Release: $version"
    }
    return $pretty_version
}


function mk_dir_tmp(){
    $tmp_dir = ($Env:Temp + "\" + (Get-Random -minimum 0 -maximum 999))
    New-Item $tmp_dir -type directory  > Out-Null
    return $tmp_dir
}

function rm_dir($tmp_dir){
    Remove-Item -Recurse -Force $tmp_dir
}


################
# Main program #
################

foreach ($search_dir in $search_root){
    foreach ($filename in Get-ChildItem -Recurse -Path $search_dir\ | select -expand FullName){

        # JBoss EAP 6
        if ($filename -like '*jboss-modules.jar*' -And -Not ($filename -like '*installation\patches*'))  {
#            $version = get_zipped_file_value $filename 'META-INF/maven/org.jboss.modules/jboss-modules/pom.properties' '.*version=(.*)'
#            $pretty_version = jboss_pretty_version $version
#            $asset = @{"asset" = "JBoss $pretty_version"; "path" = $filename}
#            $assets += $asset

            $tmp_dir = mk_dir_tmp
            extract_file $filename 'META-INF/maven/org.jboss.modules/jboss-modules/pom.properties' $tmp_dir
            $version = get_value "$tmp_dir/pom.properties" '.*version=(.*)'
            $pretty_version = jboss_pretty_version $version
            $asset = @{"asset" = "JBoss $pretty_version"; "path" = $filename}
            rm_dir $tmp_dir
            $assets += $asset

        # JBoss EAP < 6
        } ElseIf ($filename -like '*jboss-as\bin\run.jar*') {
            $version = get_zipped_file_value $filename 'META-INF/MANIFEST.MF' '.*[CS]V[SN]Tag=(.*) .*'
            $pretty_version = jboss_pretty_version $version
            $asset = @{"asset" = "JBoss $pretty_version"; "path" = $filename}
            $assets += $asset

        # GlassFish 4
        } ElseIf ($filename -like '*org.glassfish.main.admingui\war\pom.properties*') {
            $version = get_value $filename '.*version=(.*)'
            $asset = @{"asset" = "GlassFish $version"; "path" = $filename}
            $assets += $asset
        }
    }
}

$out_hostname = get_hostname
$out_cores    = get_cores
$out_assets   = $assets

Set-Attr $module "hostname" $out_hostname
Set-Attr $module "cores"    $out_cores
Set-Attr $module "assets"   $out_assets

Exit-Json $module
