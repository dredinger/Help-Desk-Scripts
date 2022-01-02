@echo off
TITLE XenMobile AD Group Checker


:start
SETLOCAL ENABLEDELAYEDEXPANSION

::set variables
	set i=0
	set uname=empty
	set platform=empty
	set output=empty
	set hasXenMobile=false
	set hasXenMobileO365=false

IF %1.==. GOTO :prompt
	set uname=%1
	set platform=%2
GOTO remove


::prompt user 
:prompt
	set /p uname=Username:
	set /p platform=Platform (iOS or Android):

	IF %uname%==empty (
		echo.
		echo Empty search. Try again. & goto:commonexit
	)
	IF %platform%==empty (
		echo.
		echo Empty platform. Try again. & goto:commonExit
	)

::remove user from all groups
:remove
net group "XenMobile" %uname% /DELETE /DOMAIN
net group "XenMobileO365" %uname% /DELETE /DOMAIN
net group "SG_XenMobile_BYOD" %uname% /DELETE /DOMAIN
net group "SG_XenMobile_BYOD_O365" %uname% /DELETE /DOMAIN


::search for user's mailbox type
:searchtype
	for /f %%i in ('dsquery * domainroot -filter "&(objectCategory=person)(objectClass=user)(sAMAccountName=%uname%)" -attr msExchRecipientTypeDetails') do set output=%%i 

	::if not found, restart
	IF %output%==empty (
		echo.
		echo User not found in AD. Try again. & goto:commonExit
	)

	::if found, route
	IF /i %output%==2147483648 goto inCloud
	IF /i %output%==1 goto onprem
	IF /i %output%==128 goto mailEnabled


:onPrem
	echo.
	echo User Mailbox: On-prem user 
	IF /I "%platform%"=="iOS" (	
		net group "XenMobile" %uname% /ADD /DOMAIN
	) else (
		net group "SG_XenMobile_BYOD" %uname% /ADD /DOMAIN
	)
goto commonExit


:inCloud
	echo.
	echo User Mailbox: O365 user 
	IF /I "%platform%"=="iOS" (
		net group "XenMobileO365" %uname% /ADD /DOMAIN
	) else (
		net group "SG_XenMobile_BYOD_O365" %uname% /ADD /DOMAIN
	)
goto commonExit


:mailEnabled
	echo.
	echo User Mailbox: Non DH email. Not supported with Xen Mobile.
goto commonExit

:commonExit
	pause
	cls
	ENDLOCAL
goto prompt
