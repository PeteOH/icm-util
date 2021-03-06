Class MyApps.Installer
{

XData setup [ XMLNamespace = INSTALLER ]
{
<Manifest>
<Var Name="Namespace" Value="myapp"/>

<If Condition='(##class(Config.Namespaces).Exists("${Namespace}")=0)'>
  <Namespace Name="${Namespace}" Create="yes" Code="${Namespace}" Ensemble="0" Data="${Namespace}">
    <Configuration>
      <Database Name="${Namespace}" Dir="${MGRDIR}${Namespace}" Create="overwrite" Resource="%DB_${Namespace}"/>
    </Configuration>
  </Namespace>    
</If>
<Namespace Name="${Namespace}" Create="no">
  <CSPApplication Url="/csp/${Namespace}" Directory="${CSPDIR}${Namespace}" Resource=""/>
  <Import File="/tmp/prj/" Flags="ck" Recurse="true"/>
  <Invoke Class="MyApp.Utils" Method="Init" CheckStatus="1" Return="RetVal">
	<Arg Value="/csp/${Namespace}"/>
  </Invoke>
</Namespace>
</Manifest>
}

ClassMethod setup(ByRef pVars, pLogLevel As %Integer = 3, pInstaller As %Installer.Installer, pLogger As %Installer.AbstractLogger) As %Status [ CodeMode = objectgenerator, Internal ]
{
  Quit ##class(%Installer.Manifest).%Generate(%compiledclass, %code, "setup")
}

}