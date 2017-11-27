#!/bin/sh

# Name of this version of winetricks (YYYYMMDD)
# (This doesn't change often, use the sha1sum of the file when reporting problems)
WINETRICKS_VERSION=20160627

# This is a UTF-8 file
# You should see an o with two dots over it here [ö]
# You should see a micro (u with a tail) here [µ]
# You should see a trademark symbol here [™]

#--------------------------------------------------------------------
#
# Winetricks is a package manager for Win32 dlls and applications on POSIX.
# Features:
# - Consists of a single shell script - no installation required
# - Downloads packages automatically from original trusted sources
# - Points out and works around known wine bugs automatically
# - Both command-line and GUI operation
# - Can install many packages in silent (unattended) mode
# - Multiplatform; written for Linux, but supports OS X and Cygwin too
#
# Uses the following non-POSIX system tools:
# - wine is used to execute Win32 apps except on Cygwin.
# - cabextract, unrar, unzip, and 7z are needed by some verbs.
# - aria2c, wget, or curl is needed for downloading.
# - sha1sum or openssl is needed for verifying downloads.
# - zenity is needed by the GUI, though it can limp along somewhat with kdialog.
# - xdg-open (if present) or open (for OS X) is used to open download pages
#   for the user when downloads cannot be fully automated.
# - sudo is used to mount .iso images if the user cached them with -k option.
# - perl is used to munge steam config files
# On Ubuntu, the following lines can be used to install all the prerequisites:
#    sudo add-apt-repository ppa:ubuntu-wine/ppa
#    sudo apt-get update
#    sudo apt-get install cabextract p7zip unrar unzip wget wine1.7 zenity
#
# See http://winetricks.org for documentation and tutorials, including
# how to contribute changes to winetricks.
#
#--------------------------------------------------------------------
#
# Copyright
#   Copyright (C) 2007-2014 Dan Kegel <dank!kegel.com>
#   Copyright (C) 2008-2016 Austin English <austinenglish!gmail.com>
#   Copyright (C) 2010-2011 Phil Blankenship <phillip.e.blankenship!gmail.com>
#   Copyright (C) 2010-2015 Shannon VanWagner <shannon.vanwagner!gmail.com>
#   Copyright (C) 2010 Belhorma Bendebiche <amro256!gmail.com>
#   Copyright (C) 2010 Eleazar Galano <eg.galano!gmail.com>
#   Copyright (C) 2010 Travis Athougies <iammisc!gmail.com>
#   Copyright (C) 2010 Andrew Nguyen
#   Copyright (C) 2010 Detlef Riekenberg
#   Copyright (C) 2010 Maarten Lankhorst
#   Copyright (C) 2010 Rico Schüller
#   Copyright (C) 2011 Scott Jackson <sjackson2!gmx.com>
#   Copyright (C) 2011 Trevor Johnson
#   Copyright (C) 2011 Franco Junio
#   Copyright (C) 2011 Craig Sanders
#   Copyright (C) 2011 Matthew Bauer <mjbauer95>
#   Copyright (C) 2011 Giuseppe Dia
#   Copyright (C) 2011 Łukasz Wojniłowicz
#   Copyright (C) 2011 Matthew Bozarth
#   Copyright (C) 2013-2016 Andrey Gusev <andrey.goosev!gmail.com>
#   Copyright (C) 2013-2015 Hillwood Yang <hillwood!opensuse.org>
#   Copyright (C) 2013,2016 André Hentschel <nerv!dawncrow.de>
#
# License
#   This program is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later
#   version.
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Lesser General Public License for more details.
#   You should have received a copy of the GNU Lesser General Public
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#--------------------------------------------------------------------
# Coding standards:
#
# Portability:
# - Portability matters, as this script is run on many operating systems
# - No bash, zsh, or csh extensions; only use features from
#   the POSIX standard shell and utilities; see
#   http://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html
# - 'checkbashisms -p -x winetricks' should show no warnings (per Debian policy)
# - Prefer classic sh idioms as described in e.g.
#   "Portable Shell Programming" by Bruce Blinn, ISBN: 0-13-451494-7
# - If there is no universally available program for a needed function,
#   support the two most frequently available programs.
#   e.g. fall back to wget if curl is not available; likewise, support
#   both sha1sum and openssl.
# - When using Unix commands like cp, put options before filenames so it will
#   work on systems like OS X.  e.g. "rm -f foo.dat", not "rm foo.dat -f"
#
# Formatting:
# - Your terminal and editor must be configured for UTF-8
#   If you do not see an o with two dots over it here [ö], stop!
# - Do not use tabs in this file or any verbs.
# - Indent 4 spaces.
# - Try to keep line length below 80 (makes printing easier)
# - Open curly braces ('{') and 'then' at beginning of line,
#   close curlies ('}') and 'fi' should line up with the matching { or if,
#   cases aligned with 'case' and 'esac'.  For instance,
#
#      if test "$FOO" = "bar"
#      then
#         echo "FOO is bar"
#      fi
#      case "$FOO" of
#      bar) echo "FOO is still bar" ;;
#      esac
#
# Commenting:
# - Comments should explain intent in English
# - Keep functions short and well named to reduce need for comments
#
# Naming:
# Public things defined by this script, for use by verbs:
# - Variables have uppercase names starting with W_
# - Functions have lowercase names starting with w_
#
# Private things internal to this script, not for use by verbs:
# - Local variables have lowercase names starting with uppercase _W_
# - Global variables have uppercase names starting with WINETRICKS_
# - Functions have lowercase names starting with winetricks_
# FIXME: A few verbs still use winetricks-private functions or variables.
#
# Internationalization / localization:
# - Important or frequently used message should be internationalized
#   so translations can be easily added.  For example:
#     case $LANG in
#     de*) echo "Das ist die deutsche Meldung" ;;
#     *)   echo "This is the English message" ;;
#     esac
#
#--------------------------------------------------------------------

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

W_PREFIXES_ROOT="${WINE_PREFIXES:-$XDG_DATA_HOME/wineprefixes}"

# For temp files before $WINEPREFIX is available:
if [ -x "`which mktemp 2>/dev/null`" ]
then
    W_TMP_EARLY="`mktemp -d "${TMPDIR:-/tmp}/winetricks.XXXXXXXX"`"
    W_TMP_EARLY_CLEAN=1
elif [ -w "$TMPDIR" ]
then
    W_TMP_EARLY="$TMPDIR"
else
    W_TMP_EARLY="/tmp"
fi

#---- Public Functions ----

# Ask permission to continue
w_askpermission()
{
    echo "------------------------------------------------------"
    echo "$@"
    echo "------------------------------------------------------"

    if test $W_OPT_UNATTENDED
    then
        _W_timeout="--timeout 5"
    fi

    case $WINETRICKS_GUI in
    zenity) $WINETRICKS_GUI $_W_timeout --question --title=winetricks --text="`echo $@ | sed 's,\\\\,\\\\\\\\,g'`" --no-wrap;;
    kdialog) $WINETRICKS_GUI --title winetricks --warningcontinuecancel "$@" ;;
    none) printf %s "Press Y or N, then Enter: " ; read response ; test "$response" = Y || test "$response" = y;;
    esac

    if test $? -ne 0
    then
        case $LANG in
        uk*) w_die "Операція скасована." ;;
        *) w_die "Operation cancelled, quitting." ;;
        esac
        exec false
    fi

    unset _W_timeout
}

# Display info message.  Time out quickly if user doesn't click.
w_info()
{
    echo "------------------------------------------------------"
    echo "$@"
    echo "------------------------------------------------------"

    _W_timeout="--timeout 3"

    case $WINETRICKS_GUI in
    zenity) $WINETRICKS_GUI $_W_timeout --info --title=winetricks --text="`echo $@ | sed 's,\\\\,\\\\\\\\,g'`" --no-wrap;;
    kdialog) $WINETRICKS_GUI --title winetricks --msgbox "$@" ;;
    none) ;;
    esac

    unset _W_timeout
}

# Display warning message to stderr (since it is called inside redirected code)
w_warn()
{
    echo "------------------------------------------------------" >&2
    echo "$@" >&2
    echo "------------------------------------------------------" >&2

    if test $W_OPT_UNATTENDED
    then
        _W_timeout="--timeout 5"
    fi

    case $WINETRICKS_GUI in
    zenity) $WINETRICKS_GUI $_W_timeout --error --title=winetricks --text="`echo $@ | sed 's,\\\\,\\\\\\\\,g'`";;
    kdialog) $WINETRICKS_GUI --title winetricks --error "$@" ;;
    none) ;;
    esac

    unset _W_timeout
}

# Display warning message to stderr (since it is called inside redirected code)
# And give gui user option to cancel (for when used in a loop)
# If user cancels, exit status is 1
w_warn_cancel()
{
    echo "------------------------------------------------------" >&2
    echo "$@" >&2
    echo "------------------------------------------------------" >&2

    if test $W_OPT_UNATTENDED
    then
        _W_timeout="--timeout 5"
    fi

    # Zenity has no cancel button, but will set status to 1 if you click the go-away X
    case $WINETRICKS_GUI in
    zenity) $WINETRICKS_GUI $_W_timeout --error --title=winetricks --text="`echo $@ | sed 's,\\\\,\\\\\\\\,g'`";;
    kdialog) $WINETRICKS_GUI --title winetricks --warningcontinuecancel "$@" ;;
    none) ;;
    esac

    # can't unset, it clears status
}

# Display fatal error message and terminate script
w_die()
{
    w_warn "$@"

    exit 1
}

# Kill all instances of a process in a safe way (Solaris killall kills _everything_)
w_killall()
{
    kill -s KILL `pgrep $1`
}

# Execute with error checking
# Put this in front of any command that might fail
w_try()
{
    # "VAR=foo w_try cmd" fails to put VAR in the environment
    # with some versions of bash if w_try is a shell function?!
    # This is a problem when trying to pass environment variables to e.g. wine.
    # Adding an explicit export here works around it, so add any we use.
    export WINEDLLOVERRIDES
    printf '%s\n' "Executing $*"

    # On Vista, we need to jump through a few hoops to run commands in Cygwin.
    # First, .exe's need to have the executable bit set.
    # Second, only cmd can run setup programs (presumably for security).
    # If $1 ends in .exe, we know we're running on real Windows, otherwise
    # $1 would be 'wine'.
    case "$1" in
    *.exe)
        chmod +x "$1" || true # don't care if it fails
        cmd /c "$@"
        ;;
    *)
        "$@"
        ;;
    esac
    status=$?
    if test $status -ne 0
    then
        w_die "Note: command '$@' returned status $status.  Aborting."
    fi
}

w_try_7z()
{
    # $1 - directory to extract to
    # $2 - file to extract
    # Not always installed, use Windows 7-Zip as a fallback:
    if test -x "`which 7z 2>/dev/null`"
    then
        w_try 7z x "$2" -o"$1"
    else
        w_warn "Cannot find 7z.  Using Windows 7-Zip instead. (You can avoid this by installing 7z, e.g. 'sudo apt-get install p7zip-full' or 'sudo yum install p7zip p7zip-plugins')."
        WINETRICKS_OPT_SHAREDPREFIX=1 w_call 7zip
        # errors out if there is a space between -o and path
        w_try "$WINE" "$W_PROGRAMS_X86_WIN\\7-Zip\\7z.exe" x "`w_pathconv -w $2`" -o"`w_pathconv -w $1`"
    fi
}

w_try_ar()
{
    # $1 - ar file (.deb) to extract (keeping internal paths, in cwd)
    # $2 - file to extract (optional)

    # Not always installed, use Windows 7-zip as a fallback:
    if test -x "`which ar 2>/dev/null`"
    then
        w_try ar x "$@"
    else
        w_warn "Cannot find ar.  Using Windows 7-zip instead. (You can avoid this by installing binutils, e.g. 'sudo apt-get install binutils' or 'sudo yum install binutils')."
        WINETRICKS_OPT_SHAREDPREFIX=1 w_call 7zip

        # -t* prevents 7-zip from decompressing .tar.xz to .tar, see
        # https://sourceforge.net/p/sevenzip/discussion/45798/thread/8cd16946/?limit=25
        w_try "$WINE" "$W_PROGRAMS_X86_WIN\\7-Zip\\7z.exe" -t* x "`w_pathconv -w $1`"
    fi
}

w_try_cabextract()
{
    # Not always installed, but shouldn't be fatal unless it's being used
    if test ! -x "`which cabextract 2>/dev/null`"
    then
        w_die "Cannot find cabextract.  Please install it (e.g. 'sudo apt-get install cabextract' or 'sudo yum install cabextract')."
    fi

    w_try cabextract -q "$@"
}

w_try_msiexec64()
{
    if test "$W_ARCH" != "win64"
    then
        w_die "bug: 64-bit msiexec called from a $W_ARCH prefix."
    fi

    w_try "$WINE" start /wait "$W_SYSTEM64_DLLS_WIN32/msiexec.exe" $W_UNATTENDED_SLASH_Q "$@"
}

w_try_regedit()
{
    # On Windows, doesn't work without cmd /c
    case "$OS" in
    "Windows_NT") cmdc="cmd /c";;
    *) unset cmdc ;;
    esac

    w_try winetricks_early_wine $cmdc regedit $W_UNATTENDED_SLASH_S "$@"
}

w_try_regsvr()
{
    w_try "$WINE" regsvr32 $W_UNATTENDED_SLASH_S $@
}

w_try_unrar()
{
    # $1 - zipfile to extract (keeping internal paths, in cwd)

    # Not always installed, use Windows 7-Zip as a fallback:
    if test -x "`which unrar 2>/dev/null`"
    then
        w_try unrar x "$@"
    else
        w_warn "Cannot find unrar.  Using Windows 7-Zip instead. (You can avoid this by installing unrar, e.g. 'sudo apt-get install unrar' or 'sudo yum install unrar')."
        WINETRICKS_OPT_SHAREDPREFIX=1 w_call 7zip
        w_try "$WINE" "$W_PROGRAMS_X86_WIN\\7-Zip\\7z.exe" x "`w_pathconv -w $1`"
    fi
}

w_try_unzip()
{
    # $1 - directory to extract to
    # $2 - zipfile to extract
    # $3 .. $n - files to extract from the archive

    destdir="$1"
    zipfile="$2"
    shift 2

    # Not always installed, use Windows 7-Zip as a fallback:
    if test -x "`which unzip 2>/dev/null`"
    then
        # FreeBSD ships unzip, but it doesn't support self-compressed executables
        # If it fails, fall back to 7-Zip:
        unzip -o -q -d"$destdir" "$zipfile" "$@"
        ret=$?
        case $ret in
            0) return ;;
            1|*) w_warn "Unzip failed, trying Windows 7-Zip instead." ;;
        esac
    else
        w_warn "Cannot find unzip.  Using Windows 7-Zip instead. (You can avoid this by installing unzip, e.g. 'sudo apt-get install unzip' or 'sudo yum install unzip')."
    fi

    WINETRICKS_OPT_SHAREDPREFIX=1 w_call 7zip
    # errors out if there is a space between -o and path
    w_try "$WINE" "$W_PROGRAMS_X86_WIN\\7-Zip\\7z.exe" x "`w_pathconv -w $zipfile`" -o"`w_pathconv -w $destdir`" "$@"
}

w_read_key()
{
    if test ! "$W_OPT_UNATTENDED"
    then
        W_KEY=dummy_to_make_autohotkey_happy
        return 0
    fi

    mkdir -p "$W_CACHE/$W_PACKAGE"

    # backwards compatible location
    # Auth doesn't belong in cache, since restoring it requires user input
    _W_keyfile="$W_CACHE/$W_PACKAGE/key.txt"
    if ! test -f "$_W_keyfile"
    then
        _W_keyfile="$WINETRICKS_AUTH/$W_PACKAGE/key.txt"
    fi
    if ! test -f "$_W_keyfile"
    then
        # read key from user
        case $LANG in
        da*) _W_keymsg="Angiv venligst registrerings-nøglen for pakken '$_PACKAGE'"
            _W_nokeymsg="Ingen nøgle angivet"
            ;;
        de*) _W_keymsg="Bitte einen Key für Paket '$W_PACKAGE' eingeben"
            _W_nokeymsg="Keinen Key eingegeben?"
            ;;
        pl*) _W_keymsg="Proszę podać klucz dla programu '$W_PACKAGE'"
            _W_nokeymsg="Nie podano klucza"
            ;;
        ru*) _W_keymsg="Пожалуйста, введите ключ для приложения '$W_PACKAGE'"
            _W_nokeymsg="Ключ не введён"
            ;;
        uk*) _W_keymsg="Будь ласка, введіть ключ для додатка '$W_PACKAGE'"
            _W_nokeymsg="Ключ не надано"
            ;;
        zh_CN*)  _W_keymsg="按任意键为 '$W_PACKAGE'"
            _W_nokeymsg="No key given"
            ;;
        zh_TW*|zh_HK*)  _W_keymsg="按任意鍵為 '$W_PACKAGE'"
            _W_nokeymsg="No key given"
            ;;
        *)  _W_keymsg="Please enter the key for app '$W_PACKAGE'"
            _W_nokeymsg="No key given"
            ;;
        esac
        case $WINETRICKS_GUI in
        *zenity) W_KEY=`zenity --entry --text "$_W_keymsg"` ;;
        *kdialog) W_KEY=`kdialog --inputbox "$_W_keymsg"` ;;
        *xmessage) w_die "sorry, can't read key from GUI with xmessage" ;;
        none) printf %s "$_W_keymsg": ; read W_KEY ;;
        esac
        if test "$W_KEY" = ""
        then
            w_die "$_W_nokeymsg"
        fi
        echo "$W_KEY" > "$_W_keyfile"
    fi
    W_RAW_KEY=`cat "$_W_keyfile"`
    W_KEY=`echo $W_RAW_KEY | tr -d '[:blank:][=-=]'`
    unset _W_keyfile _W_keymsg _W_nokeymsg
}

# Convert a Windows path to a Unix path quickly.
# $1 is an absolute Windows path starting with c:\ or C:/
# with no funny business, so we can use the simplest possible
# algorithm.
winetricks_wintounix()
{
    _W_winp_="$1"
    # Remove drive letter and colon
    _W_winp="${_W_winp_#??}"
    # Prepend the location of drive c
    printf %s "$WINEPREFIX"/dosdevices/c:
    # Change backslashes to slashes
    echo $_W_winp | sed 's,\\,/,g'
}

# Convert between Unix path and Windows path
# Usage is lowest common denominator of cygpath/winepath
# so -u to convert to Unix, and -w to convert to Windows
w_pathconv()
{
    case "$OS" in
     "Windows_NT")
        # for some reason, cygpath turns some spaces into newlines?!
        cygpath "$@" | tr '\012' '\040' | sed 's/ $//'
        ;;
     *)
        case "$@" in
        -u?c:\\*|-u?C:\\*|-u?c:/*|-u?C:/*) winetricks_wintounix "$2" ;;
        *) winetricks_early_wine winepath "$@" ;;
        esac
        ;;
    esac
}

# Expand an environment variable and print it to stdout
w_expand_env()
{
    winetricks_early_wine cmd.exe /c echo "%$1%"
}

# get sha1sum string and set $_W_gotsum to it
w_get_sha1sum()
{
    local _W_file="$1"

    # See https://github.com/Winetricks/winetricks/issues/645
    # User is running winetricks from /dev/stdin
    if [ -f "$_W_file" ] || [ -h "$_W_file" ]
    then
        _W_gotsum=`$WINETRICKS_SHA1SUM < "$_W_file" | sed 's/(stdin)= //;s/ .*//'`
    else
        w_warn "$_W_file is not a regular file, not checking sha1sum"
        return
    fi
}

# verify an sha1sum
w_verify_sha1sum()
{
    _W_vs_wantsum=$1
    _W_vs_file=$2

    w_get_sha1sum "$_W_vs_file"
    if [ "$_W_gotsum"x != "$_W_vs_wantsum"x ]
    then
        w_die "sha1sum mismatch!  Rename $_W_vs_file and try again."
    fi
    unset _W_vs_wantsum _W_vs_file _W_gotsum
}

# wget outputs progress messages that look like this:
#      0K .......... .......... .......... .......... ..........  0%  823K 40s
# This function replaces each such line with the pair of lines
# 0%
# # Downloading... 823K (40s)
# It uses minimal buffering, so each line is output immediately
# and the user can watch progress as it happens.

winetricks_parse_wget_progress()
{
    # Parse a percentage, a size, and a time into $1, $2 and $3
    # then use them to create the output line.
    perl -p -e \
       '$| = 1; s/^.* +([0-9]+%) +([0-9,.]+[GMKB]) +([0-9hms,.]+).*$/\1\n# Downloading... \2 (\3)/'
}

# Execute wget, and if in GUI mode, also show a graphical progress bar
winetricks_wget_progress()
{
    case $WINETRICKS_GUI in
    zenity)
        # Usa a subshell so if the user clicks 'Cancel',
        # the --auto-kill kills the subshell, not the current shell
        (
            ${torify} wget "$@" 2>&1 |
            winetricks_parse_wget_progress | \
            $WINETRICKS_GUI --progress --width 400 --title="$_W_file" --auto-kill --auto-close
        )
        err=$?
        if test $err -gt 128
        then
            # 129 is 'killed by SIGHUP'
            # Sadly, --auto-kill only applies to parent process,
            # which was the subshell, not all the elements of the pipeline...
            # have to go find and kill the wget.
            # If we ran wget in the background, we could kill it more directly, perhaps...
            if pid=`ps augxw | grep ."$_W_file" | grep -v grep | awk '{print $2}'`
            then
                echo User aborted download, killing wget
                kill $pid
            fi
        fi
        return $err
        ;;
    *) ${torify} wget "$@" ;;
    esac
}

w_dotnet_verify()
{
    case $1 in
        dotnet11) version="1.1" ;;
        dotnet11sp1) version="1.1 SP1" ;;
        dotnet20) version="2.0" ;;
        dotnet20sp1) version="2.0 SP1" ;;
        dotnet20sp2) version="2.0 SP2" ;;
        dotnet30) version="3.0" ;;
        dotnet30sp1) version="3.0 SP1" ;;
        dotnet35) version="3.5" ;;
        dotnet35sp1) version="3.5 SP1" ;;
        dotnet40) version="4 Client" ;;
        dotnet45) version="4.5" ;;
        dotnet452) version="4.5.2" ;;
        *) echo error ; exit 1 ;;
    esac
            w_call dotnet_verifier
            # FIXME: The logfile may be useful somewhere (or at least print the location)
            w_ahk_do "
                SetTitleMatchMode, 2
                ; FIXME; this only works the first time? Check if it's already verified somehow..
                run, netfx_setupverifier.exe /q:a /c:"setupverifier2.exe"
                winwait, Verification Utility
                ControlClick, Button1
                Control, ChooseString, NET Framework $version, ComboBox1
                ControlClick, Button1 ; Verify
                loop, 60
                {
                    sleep 1000
                    process, exist, setupverifier2.exe
                    dn_pid=%ErrorLevel%
                    if dn_pid = 0
                    {
                        break
                    }
                    ifWinExist, Verification Utility, Product verification failed
                    {
                        process, close, setupverifier2.exe
                        exit 1
                    }
                    ifWinExist, Verification Utility, Product verification succeeded
                    {
                        process, close, setupverifier2.exe
                        break
                    }
                }
            "
            dn_status=$?
}

# Checks if the user can run the self-update/rollback commands
winetricks_check_update_availability()
{
    # Prevents the development file overwrite:
    if test -d "../.git"
    then
        w_warn "You're running in a dev environment. Please make a copy of the file before running this command."
        exit;
    fi

    # Checks read/write permissions on update directories
    if ! (test -r $0 && test -w $0 && test -w ${0%/*} && test -x ${0%/*})
    then
        w_warn "You don't have the proper permissions to run this command. Try again with sudo or as root."
        exit;
    fi
}

winetricks_selfupdate()
{
    winetricks_check_update_availability

    _W_filename="${0##*/}"
    _W_rollback_file="${0}.bak"
    _W_update_file="${0}.update"

    _W_tmpdir=${TMPDIR:-/tmp}
    _W_tmpdir="`mktemp -d "$_W_tmpdir/$_W_filename.XXXXXXXX"`"

    w_download_to $_W_tmpdir https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
    w_try mv $_W_tmpdir/$_W_filename $_W_update_file.gz
    w_try gunzip $_W_update_file.gz
    w_try rmdir $_W_tmpdir

    w_try cp $0 $_W_rollback_file
    w_try chmod -x $_W_rollback_file

    w_try mv $_W_update_file $0
    w_try chmod +x $0

    w_warn "Update finished! The current version is '`$0 -V`'. Use 'winetricks --update-rollback' to return to the previous version."

    exit;
}

winetricks_selfupdate_rollback()
{
    winetricks_check_update_availability

    _W_rollback_file="${0}.bak"

    if test -f $_W_rollback_file
    then
        w_try mv $_W_rollback_file $0
        w_try chmod +x $0
        w_warn "Rollback finished! The current version is '`$0 -V`'."
    else
        w_warn "Nothing to rollback."
    fi
    exit;
}

# Download a file
# Usage: w_download_to packagename url [sha1sum [filename [cookie jar]]]
# Caches downloads in winetrickscache/$packagename
w_download_to()
{
    _W_packagename="$1"
    _W_url="$2"
    _W_sum="$3"
    _W_file="$4"
    _W_cookiejar="$5"

    case $_W_packagename in
    .) w_die "bug: please do not download packages to top of cache" ;;
    esac

    if echo "$_W_url" | grep ' '
    then
        w_die "bug: please use %20 instead of literal spaces in urls, curl rejects spaces, and they make life harder for linkcheck.sh"
    fi
    if [ "$_W_file"x = ""x ]
    then
        _W_file=`basename "$_W_url"`
    fi
    _W_cache="$W_CACHE/$_W_packagename"

    if test ! -d "$_W_cache"
    then
        w_try mkdir -p "$_W_cache"
    fi

    # Try download twice
    checksum_ok=""
    tries=0
    while test $tries -lt 2
    do
        tries=`expr $tries + 1`

        if test -s "$_W_cache/$_W_file"
        then
            if test "$3"
            then
                if test $tries = 1
                then
                    # The cache was full.  If the file is larger than 500 MB,
                    # don't checksum it, that just annoys the user.
                    if test `du -k "$_W_cache/$_W_file" | cut -f1` -gt 500000
                    then
                        checksum_ok=1
                        break
                    fi
                fi
                # If checksum matches, declare success and exit loop
                w_get_sha1sum "$_W_cache/$_W_file"
                if [ "$_W_gotsum"x = "$3"x ]
                then
                    checksum_ok=1
                    break
                fi
                if test ! "$WINETRICKS_CONTINUE_DOWNLOAD"
                then
                    w_warn "Checksum for $_W_cache/$_W_file did not match, retrying download"
                    mv -f "$_W_cache/$_W_file" "$_W_cache/$_W_file".bak
                fi
            else
                # file exists, no checksum known, declare success and exit loop
                break
            fi
        elif test -f "$_W_cache/$_W_file"
        then
            # zero-length file, just delete before retrying
            rm "$_W_cache/$_W_file"
        fi

        _W_dl_olddir=`pwd`
        cd "$_W_cache"
        # Mac folks tend to have curl rather than wget
        # On Mac, 'which' doesn't return good exit status
        # Need to jam in --header "Accept-Encoding: gzip,deflate" else
        # redhat.com decompresses liberation-fonts.tar.gz!
        # Note: this causes other sites to compress downloads, hence
        # the kludge further down.  See http://code.google.com/p/winezeug/issues/detail?id=77
        echo Downloading $_W_url to $_W_cache

        # For sites that prefer Mozilla in the user-agent header, set W_BROWSERAGENT=1
        case "$W_BROWSERAGENT" in
        1) _W_agent="Mozilla/5.0 (compatible; Konqueror/2.1.1; X11)" ;;
        *) _W_agent= ;;
        esac

        case "$WINETRICKS_OPT_TORIFY" in
        1) torify=torify ; if [ ! -x "$(which torify 2>/dev/null)" ] ; then
           w_die "--torify was used, but torify is not installed, please install it." ; exit 1 ; fi ;;
        *) torify= ;;
        esac

        if [ -x "$(which aria2c 2>/dev/null)" ]
        then
            # (Slightly fancy) aria2c support
            # See https://github.com/Winetricks/winetricks/issues/612
            # --daemon=false --enable-rpc=false to ensure aria2c doesnt go into the background after starting
            #   and prevent any attempts to rebind on the RPC interface specified in someone's config.
            # --input-file='' if the user config has a input-file specified then aria2 will read it and
            #   attempt to download everything in that input file again.
            # --save-session='' if the user has specified save-session in their config, their session will be
            #   ovewritten by the new aria2 process
            # http-accept-gzip=true (still needed) ?

            # torify needs --async-dns=false, see https://github.com/tatsuhiro-t/aria2/issues/613
            case $WINETRICKS_OPT_TORIFY in
            1) torify aria2c --async-dns=false --continue --daemon=false --dir "$_W_cache"  --enable-rpc=false --input-file='' \
                --max-connection-per-server=5 --out "$_W_file" --save-session='' --stream-piece-selector=geom "$_W_url" ;;
            *) aria2c --continue --daemon=false --dir "$_W_cache"  --enable-rpc=false --input-file='' \
                --max-connection-per-server=5 --out "$_W_file" --save-session='' --stream-piece-selector=geom "$_W_url" ;;
            esac
        elif [ -x "`which wget 2>/dev/null`" ]
        then
           # Use -nd to insulate ourselves from people who set -x in WGETRC
           # [*] --retry-connrefused works around the broken sf.net mirroring
           # system when downloading corefonts
           # [*] --read-timeout is useful on the adobe server that doesn't
           # close the connection unless you tell it to (control-C or closing
           # the socket)
           winetricks_wget_progress \
               -O "$_W_file" -nd \
               -c --read-timeout=300 --retry-connrefused \
               --header "Accept-Encoding: gzip,deflate" \
               ${_W_cookiejar:+--load-cookies "$_W_cookiejar"} \
               ${_W_agent:+--user-agent="$_W_agent"} \
               "$_W_url"
        elif [ -x "`which curl 2>/dev/null`" ]
        then
           # curl doesn't get filename from the location given by the server!
           # fortunately, we know it
           $torify curl -L -o "$_W_file" -C - \
               --header "Accept-Encoding: gzip,deflate" \
               ${_W_cookiejar:+--cookie "$_W_cookiejar"} \
               ${_W_agent:+--user-agent "$_W_agent"} \
               "$_W_url"
        else
            w_die "Please install wget or aria2c (or, if those aren't available, curl)"
        fi
        if test $? = 0
        then
            # Need to decompress .exe's that are compressed, else Cygwin fails
            # Also affects ttf files on github
            _W_filetype=`which file 2>/dev/null`
            case $_W_filetype-$_W_file in
            /*-*.exe|/*-*.ttf|/*-*.zip)
                case `file "$_W_file"` in
                *:*gzip*) mv "$_W_file" "$_W_file.gz"; gunzip < "$_W_file.gz" > "$_W_file";;
                esac
            esac

            # On Cygwin, .exe's must be marked +x
            case "$_W_file" in
            *.exe) chmod +x "$_W_file" ;;
            esac

            cd "$_W_dl_olddir"
            unset _W_dl_olddir
        elif test $tries = 2
        then
            test -f "$_W_file" && rm "$_W_file"
            w_die "Downloading $_W_url failed"
        fi
        # Download from the Wayback Machine on second try
        _W_url="https://web.archive.org/web/$_W_url"
    done

    if test "$3" && test ! "$checksum_ok"
    then
        w_verify_sha1sum $3  "$_W_cache/$_W_file"
    fi
}

# Open a folder for the user in the specified directory
# Usage: w_open_folder directory
w_open_folder()
{
    for _W_cmd in xdg-open open cygstart true
    do
        _W_cmdpath=`which $_W_cmd`
        if test -n "$_W_cmdpath"
        then
            break
        fi
    done
    $_W_cmd "$1" &
    unset _W_cmd _W_cmdpath
}

# Open a web browser for the user to the given page
# Usage: w_open_webpage url
w_open_webpage()
{
    # See http://www.dwheeler.com/essays/open-files-urls.html
    for _W_cmd in xdg-open sdtwebclient cygstart open firefox true
    do
        _W_cmdpath=`which $_W_cmd`
        if test -n "$_W_cmdpath"
        then
            break
        fi
    done
    $_W_cmd "$1" &
    unset _W_cmd _W_cmdpath
}

# Download a file
# Usage: w_download url [sha1sum [filename [cookie jar]]]
# Caches downloads in winetrickscache/$W_PACKAGE
w_download()
{
    w_download_to $W_PACKAGE "$@"
}

# Download one or more files via BitTorrent
# Usage: w_download_torrent [foo.torrent]
# Caches downloads in $W_CACHE/$W_PACKAGE, torrent files are assumed to be there
# If no foo.torrent is given, will add ALL .torrent files in $W_CACHE/$W_PACKAGE
w_download_torrent()
{
    # FIXME: figure out how to extract the filename from the .torrent file
    # so callers don't need to check if the files are already downloaded.

    w_call utorrent

    UT_WINPATH="$W_CACHE_WIN\\$W_PACKAGE"
    cd "$W_CACHE/$W_PACKAGE"

    if [ "$2"x != ""x ] # foo.torrent parameter supplied
    then
        w_try "$WINE" utorrent "/DIRECTORY" "$UT_WINPATH" "$UT_WINPATH\\$2" &
    else # grab all torrents
        for torrent in `ls *.torrent`
        do
            w_try "$WINE" utorrent "/DIRECTORY" "$UT_WINPATH" "$UT_WINPATH\\$torrent" &
        done
    fi

    # Start uTorrent, have it wait until all downloads are finished
    w_ahk_do "
        SetTitleMatchMode, 2
        winwait, Torrent
        Loop
        {
            sleep 6000
            ifwinexist, Torrent, default
            {
                ;should uTorrent be the default torrent app?
                controlclick, Button1, Torrent, default  ; yes
                continue
            }
            ifwinexist, Torrent, already
            {
                ;torrent already registered, fine
                controlclick, Button1, Torrent, default  ; yes
                continue
            }
            ifwinexist, Torrent, Bandwidth
            {
                ;Cancels bandwidth test on first run of uTorrent
                controlclick, Button5, Torrent, Bandwidth
                continue
            }
            ifwinexist, Torrent, version
            {
                ;Decline upgrade to newer version
                controlclick, Button3, Torrent, version
                controlclick, Button2, Torrent, version
                continue
            }
            break
        }
        ;Sets parameter to close uTorrent once all downloads are complete
        winactivate, Torrent 2.0
        send !o
        send a{Down}{Enter}
        winwaitclose, Torrent 2.0
    "
}

w_download_manual_to()
{
    _W_packagename="$1"
    _W_url="$2"
    _W_file="$3"
    _W_sha1sum="$4"

    case "$media" in
    "download")
        w_info "FAIL: bug: media type is download, but w_download_manual was called.  Programmer, please change verb's media type to manual_download."
        ;;
    esac

    case $LANG in
    da*) _W_dlmsg="Hent venligst filen $_W_file fra $_W_url og placér den i $W_CACHE/$_W_packagename, kør derefter dette skript.";;
    de*) _W_dlmsg="Bitte laden Sie $_W_file von $_W_url runter, stellen Sie's in $W_CACHE/$_W_packagename, dann wiederholen Sie dieses Kommando.";;
    pl*) _W_dlmsg="Proszę pobrać plik $_W_file z $_W_url, następnie umieścić go w $W_CACHE/$_W_packagename, a na końcu uruchomić ponownie ten skrypt.";;
    ru*) _W_dlmsg="Пожалуйста, скачайте файл $_W_file по адресу $_W_url, и поместите его в $W_CACHE/$_W_packagename, а затем запустите winetricks заново.";;
    uk*) _W_dlmsg="Будь ласка, звантажте $_W_file з $_W_url, розташуйте в $W_CACHE/$_W_packagename, потім запустіть скрипт знову.";;
    zh_CN*) _W_dlmsg="请从 $_W_url 下载 $_W_file，并置放于 $W_CACHE/$_W_packagename, 然后重新运行 winetricks.";;
    zh_TW*|zh_HK*) _W_dlmsg="請從 $_W_url 下載 $_W_file，并置放於 $W_CACHE/$_W_packagename, 然后重新執行 winetricks.";;
    *) _W_dlmsg="Please download $_W_file from $_W_url, place it in $W_CACHE/$_W_packagename, then re-run this script.";;
    esac

    if ! test -f "$W_CACHE/$_W_packagename/$_W_file"
    then
        mkdir -p "$W_CACHE/$_W_packagename"
        w_open_folder "$W_CACHE/$_W_packagename"
        w_open_webpage "$_W_url"
        sleep 3   # give some time for web browser to open
        w_die "$_W_dlmsg"
        # FIXME: wait in loop until file is finished?
    fi

    if test "$_W_sha1sum"
    then
        w_verify_sha1sum $_W_sha1sum "$W_CACHE/$_W_packagename/$_W_file"
    fi

    unset _W_url _W_file _W_sha1sum _W_dlmsg
}

w_download_manual()
{
    w_download_manual_to $W_PACKAGE "$@"
}

# Turn off news, overlays, and friend interaction in Steam
# Run from inside C:\Program Files\Steam
w_steam_safemode()
{
    cat > "$W_TMP/steamconfig.pl" <<"_EOF_"
#!/usr/bin/env perl
# Parse Steam's localconfig.vcf, add settings to it, and write it out again
# The file is a recursive dictionary
#
# FILE :== CONTAINER
#
# VALUE :== "name" "value" NEWLINE
#
# CONTAINER :== "name" NEWLINE "{" NEWLINE ( VALUE | CONTAINER ) * "}" NEWLINE
#
# We load it into a recursive hash.

use strict;
use warnings;

sub read_into_container{
    my( $pcontainer ) = @_;

    $_ = <FILE> || w_die "Can't read first line of container";
    /{/ || w_die "First line of container was not {";
    while (<FILE>) {
       chomp;
       if (/"([^"]*)"\s*"([^"]*)"$/) {
           ${$pcontainer}{$1} = $2;
       } elsif (/"([^"]*)"$/) {
           my( %newcon, $name );
           $name = $1;
           read_into_container(\%newcon);
           ${$pcontainer}{$name} = \%newcon;
        } elsif (/}/) {
           return;
        } else {
           w_die "huh?";
        }
    }
}

sub dump_container{
    my( $pcontainer, $indent ) = @_;
    foreach (sort(keys(%{$pcontainer}))) {
        my( $val ) = ${$pcontainer}{$_};
        if (ref $val eq 'HASH') {
            print "${indent}\"$_\"\n";
            print "${indent}{\n";
            dump_container($val, "$indent\t");
            print "${indent}}\n";
        } else {
            print "${indent}\"${_}\"\t\t\"$val\"\n";
        }
    }
}

# Disable anything unsafe or annoying
sub disable_notifications{
    my( $pcontainer ) = @_;
    ${$pcontainer}{"friends"}{"PersonaStateDesired"} = "1";
    ${$pcontainer}{"friends"}{"Notifications_ShowIngame"} = "0";
    ${$pcontainer}{"friends"}{"Sounds_PlayIngame"} = "0";
    ${$pcontainer}{"friends"}{"Notifications_ShowOnline"} = "0";
    ${$pcontainer}{"friends"}{"Sounds_PlayOnline"} = "0";
    ${$pcontainer}{"friends"}{"Notifications_ShowMessage"} = "0";
    ${$pcontainer}{"friends"}{"Sounds_PlayMessage"} = "0";
    ${$pcontainer}{"friends"}{"AutoSignIntoFriends"} = "0";
    ${$pcontainer}{"News"}{"NotifyAvailableGames"} = "0";
    ${$pcontainer}{"system"}{"EnableGameOverlay"} = "0";
}

# Read the file
my(%top);
open FILE, $ARGV[0] || w_die "can't open ".$ARGV[0];
my($line);
$line = <FILE> || w_die "Could not read first line from ".$ARGV[0];
$line =~ /"UserLocalConfigStore"/ || w_die "this is not a localconfig.vdf file";
read_into_container(\%top);

# Modify it
disable_notifications(\%top);

# Write modified file
print "\"UserLocalConfigStore\"\n";
print "{\n";
dump_container(\%top, "\t");
print "}\n";
_EOF_

for file in userdata/*/config/localconfig.vdf
do
    cp "$file" "$file.old"
    perl "$W_TMP"/steamconfig.pl "$file.old" > "$file"
done
}

w_question()
{
    case $WINETRICKS_GUI in
    *zenity) $WINETRICKS_GUI --entry --text "$1" ;;
    *kdialog) $WINETRICKS_GUI --inputbox "$1" ;;
    *xmessage) w_die "sorry, can't ask question with xmessage" ;;
    none) echo -n "$1" >&2 ; read W_ANSWER ; echo $W_ANSWER; unset W_ANSWER;;
    esac
}

# Reads steam username and password from environment, cache, or user
# If had to ask user, cache answer.
w_steam_getid()
{
    #TODO: Translate
    _W_steamidmsg="Please enter your Steam login ID (not email)"
    _W_steampasswordmsg="Please enter your Steam password"

    if test ! "$W_STEAM_ID"
    then
        if test -f "$W_CACHE"/steam_userid.txt
        then
            W_STEAM_ID=`cat "$W_CACHE"/steam_userid.txt`
        else
            W_STEAM_ID=`w_question "$_W_steamidmsg"`
            echo "$W_STEAM_ID" > "$W_CACHE"/steam_userid.txt
            chmod 600 "$W_CACHE"/steam_userid.txt
        fi
    fi
    if test ! "$W_STEAM_PASSWORD"
    then
        if test -f "$W_CACHE"/steam_password.txt
        then
            W_STEAM_PASSWORD=`cat "$W_CACHE"/steam_password.txt`
        else
            W_STEAM_PASSWORD=`w_question "$_W_steampasswordmsg"`
            echo "$W_STEAM_PASSWORD" > "$W_CACHE"/steam_password.txt
            chmod 600 "$W_CACHE"/steam_password.txt
        fi
    fi
}

# Usage:
# w_steam_install_game steamidnum windowtitle
w_steam_install_game()
{
    _W_steamid=$1
    _W_steamtitle="$2"

    w_steam_getid

    # Install the steam runtime
    WINETRICKS_OPT_SHAREDPREFIX=1 w_call steam

    # Steam puts up a bunch of windows.  Here's the sequence:
    # "Steam - Updating" - wait for it to close.  May appear twice in a row.
    # "Steam - Login" - wait for it to close (credentials already given on cmdline)
    # "Steam" (small window) - connecting, wait for it to close
    # "Steam" (large window) - the main window
    # "Steam - Updates News" - close it forcefully
    # "Install - $title" - send enter, click a couple checkboxes, send enter again
    # "Updating $title" - small download progress dialog
    # "Steam - Ready" game install done.  (Only comes up if main window not up.)

    cd "$W_PROGRAMS_X86_UNIX/Steam"
    w_ahk_do "
        SetTitleMatchMode 2
        SetWinDelay 500
        ; Run steam once until it finishes its initial update.
        ; For me, this exits at 26%.
        run steam.exe -applaunch $_W_steamid -login $W_STEAM_ID $W_STEAM_PASSWORD
        Loop
        {
            ifWinExist, Steam - Updating
            {
                winwaitclose, Steam
                process close, Steam.exe
                sleep 1000
                ; Run a second time; let it finish updating, then kill it.
                run steam.exe
                winwait Steam - Updating
                winwaitclose
                process close, Steam.exe
                ; Run a third time, have it log in, wait until it has finished connecting
                run steam.exe -applaunch $_W_steamid -login $W_STEAM_ID $W_STEAM_PASSWORD
            }
            ifWinExist, Steam Login
            {
                break
            }
            sleep 500
        }
        ; wait for login window to close
        winwaitclose

        winwait Steam  ; wait for small <<connecting>> window
        winwaitclose
    "

if [ "$STEAM_DVD" = "TRUE" ]
then
    w_ahk_do "
        ; Run a fourth time, have it install the app.
        run steam.exe -install ${W_ISO_MOUNT_LETTER}:\\
    "
else
    w_ahk_do "
        ; Run a fourth time, have it install the app.
        run steam.exe -applaunch $_W_steamid
    "
fi

    w_ahk_do "
        winwait Install - $_W_steamtitle
        if ( w_opt_unattended > 0 ) {
            send {enter}          ; next (for 1st of 3 pages of install dialog)
            sleep 1000
            click 32, 91          ; uncheck create menu item?
            click 32, 119         ; check create desktop icon?
            send {enter}          ; next (for 2nd of 3 pages of install dialog)
            ; dismiss any news dialogs, and click 'next' on third page of install dialog
            loop
            {
                sleep 1000
                ifwinexist Steam - Updates News
                {
                    winclose
                    continue
                }
                ifwinexist Install - $_W_steamtitle
                {
                    winactivate
                    send {enter}      ; next (for 3rd of 3 pages of install dialog)
                }
                ifwinnotexist Install - $_W_steamtitle
                {
                    sleep 1000
                    ifwinnotexist Install - $_W_steamtitle
                        break
                }
            }
        }
    "

if [ "$STEAM_DVD" = "TRUE" ]
then
    # Wait for install to finish
    while true
    do
        grep "SetHasAllLocalContent(true) called for $_W_steamid" "$W_PROGRAMS_X86_UNIX/Steam/logs/download_log.txt" && break
        sleep 5
    done
fi

    w_ahk_do "
        ; For DVD's: theoretically, it should be installed now, but most games want to download updates. Do that now.
        ; For regular downloads: relaunch to coax steam into showing its nice small download progress dialog
        process close, Steam.exe
        run steam.exe -login $W_STEAM_ID $W_STEAM_PASSWORD -applaunch $_W_steamid
        winwait Ready -
        process close, Steam.exe
    "

    # Not all users need this disabled, but let's play it safe for now
    if w_workaround_wine_bug 22053 "Disabling in-game notifications to prevent game crashes on some machines."
    then
        w_steam_safemode
    fi

    unset _W_steamid _W_steamtitle
}

#----------------------------------------------------------------

# Generic GOG.com installer
# Usage: game_id game_title [other_files,size [reader_control [run_command [download_id [install_dir [installer_size_and_sha1]]]]]]
# game_id
#     Used for main installer name and download url.
# game_title
#     Used for AutoHotKey and installation path in bat script.
# other_files
#     Extra installer files, in one string, space-separated.
# reader_control
#     If set, the control id of the configuration panel checkbox controling
#     Adobe Reader installation.
#     Some games don't have it, some games do with different ids.
# run_command
#     Used for bat script, relative to installation path.
# download_id
#     For games which download url doesn't match their game_id
# install_dir
#     If different from game_title
# installer_size_and_sha1
#     exe file SHA1.
winetricks_load_gog()
{
    game_id="$1"
    game_title="$2"
    other_files="$3"
    reader_control="$4"
    run_command="$5"
    download_id="$6"
    install_dir="$7"
    installer_size_and_sha1="$8"

    if [ "$download_id"x = ""x ]
    then
        download_id="$game_id"
    fi
    if [ "$install_dir"x = ""x ]
    then
        install_dir="$game_title"
    fi

    installer_path="$W_CACHE/$W_PACKAGE"
    mkdir -p "$installer_path"
    installer="setup_$game_id.exe"

    if test "$installer_size_and_sha1"x = ""x
    then
        files="$installer $other_files"
    else
        files="$installer,$installer_size_and_sha1 $other_files"
    fi

    file_id=0
    for file_and_size_and_sha1 in $files
    do
        case "$file_and_size_and_sha1" in
        *,*,*)
            sha1sum=`echo $file_and_size_and_sha1 | sed "s/.*,//"`
            minsize=`echo $file_and_size_and_sha1 | sed 's/[^,]*,\([^,]*\),.*/\1/'`
            file=`echo $file_and_size_and_sha1 | sed 's/,.*//'`
            ;;
        *,*)
            sha1sum=""
            minsize=`echo $file_and_size_and_sha1 | sed 's/.*,//'`
            file=`echo $file_and_size_and_sha1 | sed 's/,.*//'`
            ;;
        *)
            sha1sum=""
            minsize=1
            file=$file_and_size_and_sha1
            ;;
        esac
        file_path="$installer_path/$file"
        if ! test -s "$file_path" || test `stat -Lc%s "$file_path"` -lt $minsize
        then
            # FIXME: bring back automated download
            w_info "You have to be logged in to GOG, and you have to own the game, for the following URL to work.  Otherwise it gets a 404."
            w_download_manual "https://www.gog.com/en/download/game/$download_id/$file_id" "$file"
            check_sha1=1
            filesize=`stat -Lc%s "$file_path"`
            if test $minsize -gt 1 && test $filesize -ne $minsize
            then
                check_sha1=""
                w_warn "Expected file size $minsize, please report new size $filesize."
            fi
            if test "$check_sha1" != "" && test "$sha1sum"x != ""x
            then
                w_verify_sha1sum "$sha1sum" "$file_path"
            fi
        fi
        file_id=`expr $file_id + 1`
    done

    cd "$installer_path"
    w_ahk_do "
        run $installer
        WinWait, Setup - $game_title, Start installation
        ControlGet, checkbox_state, Checked,, TCheckBox1 ; EULA
        if (checkbox_state != 1) {
            ControlClick, TCheckBox1
        }
        if (\"$reader_control\") {
            ControlClick, TMCoPShadowButton1 ; Options
            Loop, 10
            {
                ControlGet, visible, Visible,, $reader_control
                if (visible)
                {
                    break
                }
                Sleep, 1000
            }
            ControlGet, checkbox_state, Checked,, $reader_control ; Unckeck Adobe/Foxit Reader
            if (checkbox_state != 0) {
                ControlClick, $reader_control
            }
        }
        ControlClick, TMCoPShadowButton2 ; Start Installation
        WinWait, Setup - $game_title, Exit Installer
        ControlClick, TMCoPShadowButton1 ; Exit Installer
        "
}

#----------------------------------------------------------------


# Usage: w_mount "volume name" [filename-to-check [discnum]]
# Some games have two volumes with identical volume names.
# For these, please specify discnum 1 for first disc, discnum 2 for 2nd, etc.,
# else caching can't work.
# FIXME: should take mount option 'unhide' for poorly mastered discs
w_mount()
{
    if test "$3"
    then
        WINETRICKS_IMG="$W_CACHE/$W_PACKAGE/$1-$3.iso"
    else
        WINETRICKS_IMG="$W_CACHE/$W_PACKAGE/$1.iso"
    fi
    mkdir -p "$W_CACHE/$W_PACKAGE"

    if test -f "$WINETRICKS_IMG"
    then
        winetricks_mount_cached_iso
    else
        if test "$WINETRICKS_OPT_KEEPISOS" = 0 || test "$2"
        then
            while true
            do
                winetricks_mount_real_volume "$1"
                if test "$2" = "" || test -f "$W_ISO_MOUNT_ROOT/$2"
                then
                    break
                else
                    w_warn "Wrong disc inserted, $2 not found."
                fi
            done
        fi

        case "$WINETRICKS_OPT_KEEPISOS" in
        1)
            winetricks_cache_iso "$1"
            winetricks_mount_cached_iso
            ;;
        esac
    fi
}

w_umount()
{
    if test "$WINE" = ""
    then
        # Windows
        winetricks_load_vcdmount
        cd "$VCD_DIR"
        w_try vcdmount.exe /u
    else
        echo "Running $WINETRICKS_SUDO umount $W_ISO_MOUNT_ROOT"
        case "$WINETRICKS_SUDO" in
        gksudo)
          # -l lazy unmount in case executable still running
          $WINETRICKS_SUDO "umount -l $W_ISO_MOUNT_ROOT"
          w_try $WINETRICKS_SUDO "rm -rf $W_ISO_MOUNT_ROOT"
          ;;
        *)
          $WINETRICKS_SUDO umount -l $W_ISO_MOUNT_ROOT
          w_try $WINETRICKS_SUDO rm -rf $W_ISO_MOUNT_ROOT
          ;;
        esac
        "$WINE" eject ${W_ISO_MOUNT_LETTER}:
        rm -f "$WINEPREFIX"/dosdevices/${W_ISO_MOUNT_LETTER}:
        rm -f "$WINEPREFIX"/dosdevices/${W_ISO_MOUNT_LETTER}::
    fi
}

w_ahk_do()
{
    if ! test -f "$W_CACHE/ahk/AutoHotkey.exe"
    then
        W_BROWSERAGENT=1 \
        w_download_to ahk http://www.autohotkey.com/download/AutoHotkey104805.zip b3981b13fbc45823131f69d125992d6330212f27
        w_try_unzip "$W_CACHE/ahk" "$W_CACHE/ahk/AutoHotkey104805.zip" AutoHotkey.exe AU3_Spy.exe
        chmod +x "$W_CACHE/ahk/AutoHotkey.exe"
    fi

    _W_CR=`printf \\\\r`
    cat <<_EOF_ | sed "s/\$/$_W_CR/" > "$W_TMP"/tmp.ahk
w_opt_unattended = ${W_OPT_UNATTENDED:-0}
$@
_EOF_
    w_try "$WINE" "$W_CACHE_WIN\\ahk\\AutoHotkey.exe" "$W_TMP_WIN"\\tmp.ahk
    unset _W_CR
}

# Function to protect Wine-specific sections of code.
# Outputs a message to console explaining what's being skipped.
# Usage:
#   if w_skip_windows name-of-operation
#   then
#      return
#   fi
#   ... do something that doesn't make sense on Windows ...

w_skip_windows()
{
    case "$OS" in
    "Windows_NT")
        echo "Skipping operation '$1' on Windows"
        return 0
        ;;
    esac
    return 1
}

w_override_dlls()
{
    w_skip_windows w_override_dlls && return

    _W_mode=$1
    case $_W_mode in
    *=*)
        w_die "w_override_dlls: unknown mode $_W_mode.
Usage: 'w_override_dlls mode[,mode] dll ...'." ;;
    disabled)
        _W_mode="" ;;
    esac
    shift
    echo Using $_W_mode override for following DLLs: $@
    cat > "$W_TMP"/override-dll.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
_EOF_
    while test "$1" != ""
    do
        case "$1" in
        comctl32)
           rm -rf "$W_WINDIR_UNIX"/winsxs/manifests/x86_microsoft.windows.common-controls_6595b64144ccf1df_6.0.2600.2982_none_deadbeef.manifest
           ;;
        esac

        if [ "$_W_mode" = default ]
        then
            # To delete a registry key, give an unquoted dash as value
            echo "\"*$1\"=-" >> "$W_TMP"/override-dll.reg
        else
            # Note: if you want to override even DLLs loaded with an absolute
            # path, you need to add an asterisk:
            echo "\"*$1\"=\"$_W_mode\"" >> "$W_TMP"/override-dll.reg
            #echo "\"$1\"=\"$_W_mode\"" >> "$W_TMP"/override-dll.reg
        fi

        shift
    done

    w_try_regedit "$W_TMP_WIN"\\override-dll.reg

    unset _W_mode
}

w_override_no_dlls()
{
    w_skip_windows override && return

    "$WINE" regedit /d 'HKEY_CURRENT_USER\Software\Wine\DllOverrides'
}

w_override_all_dlls()
{
    # Disable all known native Microsoft DLLs in favor of Wine's built-in ones
    # Generated with
    # find ~/wine-git/dlls -maxdepth 1 -type d -print | sed 's,.*/,,' | sort | fmt -50 | sed 's/$/ \\/'
    # Last updated: 2015-09-28
    w_override_dlls builtin \
        acledit aclui activeds actxprxy adsiid advapi32 \
        advpack amstream api-ms-win-core-com-l1-1-0 \
        api-ms-win-core-console-l1-1-0 \
        api-ms-win-core-datetime-l1-1-0 \
        api-ms-win-core-datetime-l1-1-1 \
        api-ms-win-core-debug-l1-1-0 \
        api-ms-win-core-debug-l1-1-1 \
        api-ms-win-core-errorhandling-l1-1-0 \
        api-ms-win-core-errorhandling-l1-1-1 \
        api-ms-win-core-errorhandling-l1-1-2 \
        api-ms-win-core-fibers-l1-1-0 \
        api-ms-win-core-fibers-l1-1-1 \
        api-ms-win-core-file-l1-1-0 \
        api-ms-win-core-file-l1-2-0 \
        api-ms-win-core-file-l2-1-0 \
        api-ms-win-core-file-l2-1-1 \
        api-ms-win-core-handle-l1-1-0 \
        api-ms-win-core-heap-l1-1-0 \
        api-ms-win-core-heap-l1-2-0 \
        api-ms-win-core-heap-obsolete-l1-1-0 \
        api-ms-win-core-interlocked-l1-1-0 \
        api-ms-win-core-interlocked-l1-2-0 \
        api-ms-win-core-io-l1-1-1 \
        api-ms-win-core-kernel32-legacy-l1-1-0 \
        api-ms-win-core-libraryloader-l1-1-0 \
        api-ms-win-core-libraryloader-l1-1-1 \
        api-ms-win-core-localization-l1-2-0 \
        api-ms-win-core-localization-l1-2-1 \
        api-ms-win-core-localization-obsolete-l1-1-0 \
        api-ms-win-core-localregistry-l1-1-0 \
        api-ms-win-core-memory-l1-1-0 \
        api-ms-win-core-memory-l1-1-1 \
        api-ms-win-core-misc-l1-1-0 \
        api-ms-win-core-namedpipe-l1-1-0 \
        api-ms-win-core-namedpipe-l1-2-0 \
        api-ms-win-core-processenvironment-l1-1-0 \
        api-ms-win-core-processenvironment-l1-2-0 \
        api-ms-win-core-processthreads-l1-1-0 \
        api-ms-win-core-processthreads-l1-1-1 \
        api-ms-win-core-processthreads-l1-1-2 \
        api-ms-win-core-profile-l1-1-0 \
        api-ms-win-core-psapi-l1-1-0 \
        api-ms-win-core-registry-l1-1-0 \
        api-ms-win-core-rtlsupport-l1-1-0 \
        api-ms-win-core-rtlsupport-l1-2-0 \
        api-ms-win-core-shlwapi-legacy-l1-1-0 \
        api-ms-win-core-string-l1-1-0 \
        api-ms-win-core-synch-l1-1-0 \
        api-ms-win-core-synch-l1-2-0 \
        api-ms-win-core-sysinfo-l1-1-0 \
        api-ms-win-core-sysinfo-l1-2-0 \
        api-ms-win-core-sysinfo-l1-2-1 \
        api-ms-win-core-threadpool-legacy-l1-1-0 \
        api-ms-win-core-timezone-l1-1-0 \
        api-ms-win-core-url-l1-1-0 \
        api-ms-win-core-util-l1-1-0 \
        api-ms-win-core-winrt-error-l1-1-0 \
        api-ms-win-core-winrt-error-l1-1-1 \
        api-ms-win-core-winrt-l1-1-0 \
        api-ms-win-core-winrt-string-l1-1-0 \
        api-ms-win-core-xstate-l2-1-0 \
        api-ms-win-crt-conio-l1-1-0 \
        api-ms-win-crt-convert-l1-1-0 \
        api-ms-win-crt-environment-l1-1-0 \
        api-ms-win-crt-filesystem-l1-1-0 \
        api-ms-win-crt-heap-l1-1-0 \
        api-ms-win-crt-locale-l1-1-0 \
        api-ms-win-crt-math-l1-1-0 \
        api-ms-win-crt-multibyte-l1-1-0 \
        api-ms-win-crt-private-l1-1-0 \
        api-ms-win-crt-process-l1-1-0 \
        api-ms-win-crt-runtime-l1-1-0 \
        api-ms-win-crt-stdio-l1-1-0 \
        api-ms-win-crt-string-l1-1-0 \
        api-ms-win-crt-time-l1-1-0 \
        api-ms-win-crt-utility-l1-1-0 \
        api-ms-win-downlevel-advapi32-l1-1-0 \
        api-ms-win-downlevel-advapi32-l2-1-0 \
        api-ms-win-downlevel-normaliz-l1-1-0 \
        api-ms-win-downlevel-ole32-l1-1-0 \
        api-ms-win-downlevel-shell32-l1-1-0 \
        api-ms-win-downlevel-shlwapi-l1-1-0 \
        api-ms-win-downlevel-shlwapi-l2-1-0 \
        api-ms-win-downlevel-user32-l1-1-0 \
        api-ms-win-downlevel-version-l1-1-0 \
        api-ms-win-eventing-provider-l1-1-0 \
        api-ms-win-ntuser-dc-access-l1-1-0 \
        api-ms-win-security-base-l1-1-0 \
        api-ms-win-security-base-l1-2-0 \
        api-ms-win-security-sddl-l1-1-0 \
        api-ms-win-service-core-l1-1-1 \
        api-ms-win-service-management-l1-1-0 \
        api-ms-win-service-winsvc-l1-2-0 apphelp \
        appwiz.cpl atl atl100 atl110 atl80 atl90 authz \
        avicap32 avifil32 avifile.dll16 avrt bcrypt \
        browseui cabinet capi2032 cards cfgmgr32 clusapi \
        combase comcat comctl32 comdlg32 commdlg.dll16 \
        comm.drv16 compobj.dll16 compstui comsvcs connect \
        credui crtdll crypt32 cryptdlg cryptdll cryptext \
        cryptnet cryptui ctapi32 ctl3d32 ctl3d.dll16 \
        ctl3dv2.dll16 d2d1 d3d10 d3d10_1 d3d10core \
        d3d11 d3d8 d3d9 d3dcompiler_33 d3dcompiler_34 \
        d3dcompiler_35 d3dcompiler_36 d3dcompiler_37 \
        d3dcompiler_38 d3dcompiler_39 d3dcompiler_40 \
        d3dcompiler_41 d3dcompiler_42 d3dcompiler_43 \
        d3dcompiler_46 d3dcompiler_47 d3dim d3drm \
        d3dx10_33 d3dx10_34 d3dx10_35 d3dx10_36 d3dx10_37 \
        d3dx10_38 d3dx10_39 d3dx10_40 d3dx10_41 d3dx10_42 \
        d3dx10_43 d3dx11_42 d3dx11_43 d3dx9_24 d3dx9_25 \
        d3dx9_26 d3dx9_27 d3dx9_28 d3dx9_29 d3dx9_30 \
        d3dx9_31 d3dx9_32 d3dx9_33 d3dx9_34 d3dx9_35 \
        d3dx9_36 d3dx9_37 d3dx9_38 d3dx9_39 d3dx9_40 \
        d3dx9_41 d3dx9_42 d3dx9_43 d3dxof davclnt \
        dbgeng dbghelp dciman32 ddeml.dll16 ddraw \
        ddrawex devenum dhcpcsvc difxapi dinput \
        dinput8 dispdib.dll16 dispex display.drv16 \
        dlls dmband dmcompos dmime dmloader dmscript \
        dmstyle dmsynth dmusic dmusic32 dnsapi dplay \
        dplayx dpnaddr dpnet dpnhpast dpnlobby dpvoice \
        dpwsockx drmclien dsound dssenh dswave dwmapi \
        dwrite dxdiagn dxerr8 dxerr9 dxgi dxguid dxva2 \
        evr explorerframe ext-ms-win-gdi-devcaps-l1-1-0 \
        faultrep fltlib fntcache fontsub fusion fwpuclnt \
        gameux gdi32 gdi.exe16 gdiplus glu32 gphoto2.ds \
        gpkcsp hal hhctrl.ocx hid hidclass.sys hlink \
        hnetcfg httpapi iccvid icmp ieframe ifsmgr.vxd \
        imaadp32.acm imagehlp imm32 imm.dll16 inetcomm \
        inetcpl.cpl inetmib1 infosoft initpki inkobj \
        inseng iphlpapi itircl itss joy.cpl jscript \
        jsproxy kernel32 keyboard.drv16 krnl386.exe16 \
        ksuser ktmw32 loadperf localspl localui lz32 \
        lzexpand.dll16 mapi32 mapistub mciavi32 mcicda \
        mciqtz32 mciseq mciwave mf mfplat mfreadwrite \
        mgmtapi midimap mlang mmcndmgr mmdevapi \
        mmdevldr.vxd mmsystem.dll16 monodebg.vxd \
        mountmgr.sys mouse.drv16 mpr mprapi msacm32 \
        msacm32.drv msacm.dll16 msadp32.acm msasn1 \
        mscat32 mscms mscoree msctf msctfp msdaps \
        msdmo msftedit msg711.acm msgsm32.acm mshtml \
        mshtml.tlb msi msident msimg32 msimsg msimtf \
        msisip msisys.ocx msls31 msnet32 mspatcha msrle32 \
        msscript.ocx mssign32 mssip32 mstask msvcirt \
        msvcm80 msvcm90 msvcp100 msvcp110 msvcp120 \
        msvcp120_app msvcp60 msvcp70 msvcp71 msvcp80 \
        msvcp90 msvcr100 msvcr110 msvcr120 msvcr120_app \
        msvcr70 msvcr71 msvcr80 msvcr90 msvcrt msvcrt20 \
        msvcrt40 msvcrtd msvfw32 msvidc32 msvideo.dll16 \
        mswsock msxml msxml2 msxml3 msxml4 msxml6 \
        nddeapi ndis.sys netapi32 netcfgx netprofm \
        newdev normaliz npmshtml npptools ntdll ntdsapi \
        ntoskrnl.exe ntprint objsel odbc32 odbccp32 \
        odbccu32 ole2conv.dll16 ole2disp.dll16 ole2.dll16 \
        ole2nls.dll16 ole2prox.dll16 ole2thk.dll16 \
        ole32 oleacc oleaut32 olecli32 olecli.dll16 \
        oledb32 oledlg olepro32 olesvr32 olesvr.dll16 \
        olethk32 openal32 opencl opengl32 packager pdh \
        photometadatahandler pidgen powrprof printui \
        prntvpt propsys psapi pstorec qcap qedit qmgr \
        qmgrprxy quartz query rasapi16.dll16 rasapi32 \
        rasdlg regapi resutils riched20 riched32 \
        rpcrt4 rsabase rsaenh rstrtmgr rtutils \
        samlib sane.ds scarddlg sccbase schannel \
        schedsvc scrrun scsiport.sys secur32 security \
        sensapi serialui setupapi setupx.dll16 sfc \
        sfc_os shdoclc shdocvw shell32 shell.dll16 \
        shfolder shlwapi slbcsp slc snmpapi softpub \
        sound.drv16 spoolss stdole2.tlb stdole32.tlb \
        sti storage.dll16 stress.dll16 strmbase strmiids \
        svrapi sxs system.drv16 t2embed tapi32 taskschd \
        toolhelp.dll16 traffic twain_32 twain.dll16 \
        typelib.dll16 ucrtbase unicows updspapi url \
        urlmon usbd.sys user32 userenv user.exe16 usp10 \
        uuid uxtheme vbscript vcomp vcomp100 vcomp110 \
        vcomp90 vdhcp.vxd vdmdbg ver.dll16 version \
        vmm.vxd vnbt.vxd vnetbios.vxd vssapi vtdapi.vxd \
        vwin32.vxd w32skrnl w32sys.dll16 wbemdisp \
        wbemprox webservices wer wevtapi wiaservc \
        win32s16.dll16 win87em.dll16 winaspi.dll16 \
        windebug.dll16 windowscodecs windowscodecsext \
        winealsa.drv winecoreaudio.drv winecrt0 wined3d \
        winegstreamer winejoystick.drv winemac.drv \
        winemapi winemp3.acm wineoss.drv wineps16.drv16 \
        wineps.drv wineqtdecoder winex11.drv wing32 \
        wing.dll16 winhttp wininet winmm winnls32 \
        winnls.dll16 winscard winsock.dll16 winspool.drv \
        winsta wintab32 wintab.dll16 wintrust wlanapi \
        wldap32 wmi wmiutils wmp wmvcore wnaspi32 wow32 \
        wpcap ws2_32 wshom.ocx wsnmp32 wsock32 wtsapi32 \
        wuapi wuaueng x3daudio1_1 x3daudio1_2 x3daudio1_3 \
        x3daudio1_4 x3daudio1_5 x3daudio1_6 x3daudio1_7 \
        xapofx1_1 xapofx1_3 xapofx1_4 xapofx1_5 xaudio2_7 \
        xaudio2_8 xinput1_1 xinput1_2 xinput1_3 xinput1_4 \
        xinput9_1_0 xmllite xolehlp xpsprint xpssvcs \

        # blank line so you don't have to remove the extra trailing \
}

w_override_app_dlls()
{
    w_skip_windows w_override_app_dlls && return

    _W_app=$1
    shift
    _W_mode=$1
    shift

    # Fixme: handle comma-separated list of modes
    case $_W_mode in
    b|builtin) _W_mode=builtin ;;
    n|native) _W_mode=native ;;
    default) _W_mode=default ;;
    d|disabled)
        _W_mode="" ;;
    *)
        w_die "w_override_app_dlls: unknown mode $_W_mode.  (want native, builtin, default, or disabled)
Usage: 'w_override_app_dlls app mode dll ...'." ;;
    esac

    echo Using $_W_mode override for following DLLs when running $_W_app: $@
    (
    echo REGEDIT4
    echo ""
    echo "[HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\$_W_app\\DllOverrides]"
    ) > "$W_TMP"/override-dll.reg

    while test "$1" != ""
    do
        case "$1" in
        comctl32)
           rm -rf "$W_WINDIR_UNIX"/winsxs/manifests/x86_microsoft.windows.common-controls_6595b64144ccf1df_6.0.2600.2982_none_deadbeef.manifest
           ;;
        esac
        if [ "$_W_mode" = default ]
        then
            # To delete a registry key, give an unquoted dash as value
            echo "\"*$1\"=-" >> "$W_TMP"/override-dll.reg
        else
            # Note: if you want to override even DLLs loaded with an absolute
            # path, you need to add an asterisk:
            echo "\"*$1\"=\"$_W_mode\"" >> "$W_TMP"/override-dll.reg
            #echo "\"$1\"=\"$_W_mode\"" >> "$W_TMP"/override-dll.reg
        fi
        shift
    done

    w_try_regedit "$W_TMP_WIN"\\override-dll.reg
    rm "$W_TMP"/override-dll.reg
    unset _W_app _W_mode
}

# Has to be set in a few places...
w_set_winver()
{
    w_skip_windows w_set_winver && return
    # FIXME: This should really be done with winecfg, but it has no CLI options.

    # First, delete any lingering version info, otherwise it may conflict:
    (
    "$WINE" reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion" /v SubVersionNumber /f || true
    "$WINE" reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion" /v VersionNumber /f || true
    "$WINE" reg delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion" /v CSDVersion /f || true
    "$WINE" reg delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber /f || true
    "$WINE" reg delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion" /v CurrentVersion /f || true
    "$WINE" reg delete "HKLM\System\CurrentControlSet\Control\ProductOptions" /v ProductType /f || true
    "$WINE" reg delete "HKLM\System\CurrentControlSet\Control\ServiceCurrent" /v OS /f || true
    "$WINE" reg delete "HKLM\System\CurrentControlSet\Control\Windows" /v CSDVersion /f || true
    "$WINE" reg delete "HKCU\Software\Wine" /v Version /f || true
    "$WINE" reg delete "HKLM\\System\\CurrentControlSet\\Control\\ProductOptions" /v ProductType /f || true
    ) > /dev/null 2>&1

    case $1 in
    win31)
        echo "Setting Windows version to $1"
        cat > "$W_TMP"/set-winver.reg <<_EOF_
REGEDIT4

[HKEY_USERS\S-1-5-4\Software\Wine]
"Version"="win31"

_EOF_

        w_try_regedit "$W_TMP_WIN"\\set-winver.reg
        return
        ;;
    win95)
        # This key is only used for Windows 95/98:

        echo "Setting Windows version to $1"
        cat > "$W_TMP"/set-winver.reg <<_EOF_
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion]
"ProductName"="Microsoft Windows 95"
"SubVersionNumber"=""
"VersionNumber"="4.0.950"

_EOF_
        w_try_regedit "$W_TMP_WIN"\\set-winver.reg
        return
        ;;
    win98)
        # This key is only used for Windows 95/98:

        echo "Setting Windows version to $1"
        cat > "$W_TMP"/set-winver.reg <<_EOF_
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion]
"ProductName"="Microsoft Windows 98"
"SubVersionNumber"=" A "
"VersionNumber"="4.10.2222"

_EOF_
        w_try_regedit "$W_TMP_WIN"\\set-winver.reg
        return
        ;;
    nt40)
        # Similar to modern version, but sets two extra keys:

        echo "Setting Windows version to $1"
        cat > "$W_TMP"/set-winver.reg <<_EOF_
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion]
"CSDVersion"="Service Pack 6a"
"CurrentBuildNumber"="1381"
"CurrentVersion"="4.0"

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\ProductOptions]
"ProductType"="WinNT"

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\ServiceCurrent]
"OS"="Windows_NT"

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Windows]
"CSDVersion"=dword:00000600

_EOF_
        w_try_regedit "$W_TMP_WIN"\\set-winver.reg
        return
        ;;
    win2k)
        csdversion="Service Pack 4"
        currentbuildnumber="2195"
        currentversion="5.0"
        csdversion_hex=dword:00000400
        ;;
    winxp)
        csdversion="Service Pack 3"
        currentbuildnumber="2600"
        currentversion="5.1"
        csdversion_hex=dword:00000300
        ;;
    win2k3)
        csdversion="Service Pack 2"
        currentbuildnumber="3790"
        currentversion="5.2"
        csdversion_hex=dword:00000200
        "$WINE" reg add "HKLM\\System\\CurrentControlSet\\Control\\ProductOptions" /v ProductType /d "ServerNT" /f
        ;;
    vista)
        csdversion="Service Pack 2"
        currentbuildnumber="6002"
        currentversion="6.0"
        csdversion_hex=dword:00000200
        "$WINE" reg add "HKLM\\System\\CurrentControlSet\\Control\\ProductOptions" /v ProductType /d "WinNT" /f
        ;;
    win7)
        csdversion="Service Pack 1"
        currentbuildnumber="7601"
        currentversion="6.1"
        csdversion_hex=dword:00000100
        "$WINE" reg add "HKLM\\System\\CurrentControlSet\\Control\\ProductOptions" /v ProductType /d "WinNT" /f
        ;;
    *)
        w_die "Invalid Windows version given."
        ;;
    esac

    echo "Setting Windows version to $1"
    cat > "$W_TMP"/set-winver.reg <<_EOF_
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion]
"CSDVersion"="$csdversion"
"CurrentBuildNumber"="$currentbuildnumber"
"CurrentVersion"="$currentversion"

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Windows]
"CSDVersion"=$csdversion_hex

_EOF_
    w_try_regedit "$W_TMP_WIN"\\set-winver.reg
}

w_unset_winver()
{
    w_set_winver winxp
}

# Present app $1 with the Windows personality $2
w_set_app_winver()
{
    w_skip_windows w_set_app_winver && return

    _W_app="$1"
    _W_version="$2"
    echo "Setting $_W_app to $_W_version mode"
    (
    echo REGEDIT4
    echo ""
    echo "[HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\$_W_app]"
    echo "\"Version\"=\"$_W_version\""
    ) > "$W_TMP"/set-winver.reg

    w_try_regedit "$W_TMP_WIN"\\set-winver.reg
    rm "$W_TMP"/set-winver.reg
    unset _W_app
}

# Usage: w_wine_version OP VALUE
# All the integer comparison operators of 'test' are supported, since 'test' does the work.
# Example:
#  if w_wine_version -gt 1.3.2
#  then
#      ...
#  fi
w_wine_version()
{
    # Parse major/minor/micro/nano fields of VALUE.  Ignore nano.  Abort if major is not 1.
    case $2 in
    0*|1.0|1.0.*) w_die "bug: $2 is before 1.1, we don't bother with bugs fixed that long ago" ;;
    1.1.*) _W_minor=1; _W_micro=`echo $2 | sed 's/.*\.//'`;;
    1.2) _W_minor=2; _W_micro=0;;
    1.2.*) _W_minor=2; _W_micro=`echo $2 | sed 's/.*\.//'`;;
    1.3.*) _W_minor=3; _W_micro=`echo $2 | sed 's/.*\.//'`;;
    1.4) _W_minor=4; _W_micro=0;;
    1.4.*) _W_minor=4; _W_micro=`echo $2 | sed 's/.*\.//'`;;
    1.5.*) _W_minor=5; _W_micro=`echo $2 | sed 's/.*\.//'`;;
    1.6|1.6-rc*) _W_minor=6; _W_micro=0;;
    1.6.*) _W_minor=6; _W_micro=`echo $2 | sed 's/.*\.//'`;;
    1.7.*) _W_minor=7; _W_micro=`echo $2 | sed 's/.*\.//'`;;
    1.8.*) _W_minor=8; _W_micro=`echo $2 | sed 's/.*\.//'`;;
    1.9.*) _W_minor=9; _W_micro=`echo $2 | sed 's/.*\.//'`;;
    *) w_die "bug: unrecognized version $2";;
    esac

    # Comparing current wine version 1.$WINETRICKS_WINE_MINOR.$WINETRICKS_WINE_MICRO against 1.$_W_minor.$_W_micro
    if test $WINETRICKS_WINE_MINOR = $_W_minor
    then
        test $WINETRICKS_WINE_MICRO $1 $_W_micro || return 1
    else
        test $WINETRICKS_WINE_MINOR $1 $_W_minor || return 1
    fi
}

# Built-in self test for w_wine_version
#echo Verify that version 1.3.4 is equal to itself
#WINETRICKS_WINE_MINOR=3 WINETRICKS_WINE_MICRO=4 w_wine_version -eq 1.3.4 || w_die "fail test case wine-1.3.4 = 1.3.4"
#echo Verify that version 1.3.4 is greater than 1.2
#WINETRICKS_WINE_MINOR=3 WINETRICKS_WINE_MICRO=4 w_wine_version -gt 1.2 || w_die "fail test case wine-1.3.4 > wine-1.2"
#echo Verify that version 1.6 is greater than 1.2
#WINETRICKS_WINE_MINOR=6 WINETRICKS_WINE_MICRO=0 w_wine_version -gt 1.2 || w_die "fail test case wine-1.6 > wine-1.2"

# Usage: w_wine_version_in range ...
# True if wine version in any of the given ranges
# 'range' can be
#    val1,   (for >= val1)
#    ,val2   (for <= val2)
#    val1,val2 (for >= val1 && <= val2)
w_wine_version_in()
{
   for _W_range
   do
     _W_val1=`echo $_W_range | sed 's/,.*//'`
     _W_val2=`echo $_W_range | sed 's/.*,//'`

     # If in this range, return true
     case $_W_range in
     ,*)                                  w_wine_version   -le "$_W_val2" && unset _W_range _W_val1 _W_val2 && return 0;;
     *,) w_wine_version -ge "$_W_val1"                                    && unset _W_range _W_val1 _W_val2 && return 0;;
     *)  w_wine_version -ge "$_W_val1" && w_wine_version   -le "$_W_val2" && unset _W_range _W_val1 _W_val2 && return 0;;
     esac
   done
   unset _W_range _W_val1 _W_val2
   return 1
}

# Built-in self test for w_wine_version_in
#w_wine_version_in_test()
#{
#    WINETRICKS_WINE_MINOR=$1 WINETRICKS_WINE_MICRO=$2 w_wine_version_in $3 $4 $5 $6 || w_die "fail test case wine-1.$1.$2 in $3 $4 $5 $6"
#}
#w_wine_version_not_in_test()
#{
#    WINETRICKS_WINE_MINOR=$1 WINETRICKS_WINE_MICRO=$2 w_wine_version_in $3 $4 $5 $6 && w_die "fail test case wine-1.$1.$2 in $3 $4 $5 $6"
#}
#echo Verify that version 1.2.0 is in the range 1.2,
#w_wine_version_in_test 2 0  1.2,
#echo Verify that version 1.3.4 is in the range 1.2,
#w_wine_version_in_test 3 4  1.2,
#echo Verify that version 1.3 is not in the range ,1.2
#w_wine_version_not_in_test 3 0  ,1.2
#echo Verify that version 1.6-rc1 is in the range 1.2,
#w_wine_version_in_test 6 0  1.2,
#echo test passed

# Usage: workaround_wine_bug bugnumber [message] [good-wine-version-range ...]
# Returns true and outputs given msg if the workaround needs to be applied.
# For debugging: if you want to skip a bug's workaround, put the bug number in
# the environment variable WINETRICKS_BLACKLIST to disable it.
w_workaround_wine_bug()
{
    if test "$WINE" = ""
    then
        echo "No need to work around wine bug $1 on Windows"
        return 1
    fi
    case "$2" in
    [0-9]*) w_die "bug: want message in w_workaround_wine_bug arg 2, got $2" ;;
    "") _W_msg="";;
    *)  _W_msg="-- $2";;
    esac

    if test "$3" && w_wine_version_in $3 $4 $5 $6
    then
        echo "Current Wine does not have Wine bug $1, so not applying workaround"
        return 1
    fi

    case $1 in
    "$WINETRICKS_BLACKLIST")
        echo "Wine bug $1 workaround blacklisted, skipping"
        return 1
        ;;
    esac
    case $LANG in
    da*) w_warn "Arbejder uden om wine-fejl ${1} $_W_msg" ;;
    de*) w_warn "Wine-Fehler ${1} wird umgegangen $_W_msg" ;;
    pl*) w_warn "Obchodzenie błędu w wine ${1} $_W_msg" ;;
    ru*) w_warn "Обход ошибки ${1} $_W_msg" ;;
    uk*) w_warn "Обхід помилки ${1} $_W_msg" ;;
    zh_CN*)   w_warn "绕过 wine bug ${1} $_W_msg" ;;
    zh_TW*|zh_HK*)   w_warn "繞過 wine bug ${1} $_W_msg" ;;
    *)   w_warn "Working around wine bug ${1} $_W_msg" ;;
    esac
    winetricks_stats_log_command w_workaround_wine_bug-$1
    return 0
}

# Function for verbs to register themselves so they show up in the menu.
# Example:
# w_metadata wog games \
#   title="World of Goo Demo" \
#   pub="2D Boy" \
#   year="2008" \
#   media="download" \
#   file1="WorldOfGooDemo.1.0.exe"

w_metadata()
{
    case $WINETRICKS_OPT_VERBOSE in
        2) set -x ;;
        *) set +x ;;
    esac

    if test "$installed_exe1" || test "$installed_file1" || test "$publisher" || test "$year"
    then
        w_die "bug: stray metadata tags set: somebody forgot a backslash in a w_metadata somewhere.  Run with sh -x to see where."
    fi
    if winetricks_metadata_exists $1
    then
        w_die "bug: a verb named $1 already exists."
    fi

    _W_md_cmd="$1"
    _W_category=$2
    file="$WINETRICKS_METADATA/$_W_category/$1.vars"
    shift
    shift
    # Echo arguments to file, with double quotes around the values.
    # Used to use Perl here, but that was too slow on Cygwin.
    for arg
    do
        case "$arg" in
        installed_exe1=/*)
            w_die "bug: w_metadata $_W_md_cmd has a unix path for installed_exe1, should be a windows path";;
        installed_file1=/*)
            w_die "bug: w_metadata $_W_md_cmd has a unix path for installed_file1, should be a windows path";;
        media=download_manual)
            w_die "bug: verb $_W_md_cmd has media=download_manual, should be manual_download" ;;
        esac
        # Use longest match when stripping value,
        # and shortest match when stripping name,
        # so descriptions can have embedded equals signs
        # FIXME: backslashes get interpreted here.  This screws up
        # installed_file1 fairly often.  Fortunately, we can use forward
        # slashes in that variable instead of backslashes.
        echo ${arg%%=*}=\"${arg#*=}\"
    done > "$file"
    echo category='"'$_W_category'"' >> "$file"
    # If the problem described above happens, you'd see errors like this:
    # /tmp/w.dank.4650/metadata/dlls/comctl32.vars: 6: Syntax error: Unterminated quoted string
    # so check for lines that aren't properly quoted.

    # Do sanity check unless running on Cygwin, where it's way too slow.
    case "$OS" in
    "Windows_NT")
        ;;
    *)
        if grep '[^"]$' "$file"
        then
            w_die "bug: w_metadata $_W_md_cmd corrupt, might need forward slashes?"
        fi
        ;;
    esac
    unset _W_md_cmd

    # Restore verbosity:
    case $WINETRICKS_OPT_VERBOSE in
        1|2) set -x ;;
        *) set +x ;;
    esac
}

# Function for verbs to register their main executable [or, if name is given, other executables]
# Deprecated. No-op for backwards compatibility
w_declare_exe()
{
    w_warn "w_declare_exe is deprecated, now a noop"
}

# Checks that a conflicting verb is not already installed in the prefix
# Usage: w_conflicts verb_to_install conflicts
w_conflicts()
{
    for x in $2
    do
        if grep -qw "$x" "$WINEPREFIX/winetricks.log"
        then
            w_die "error: $1 conflicts with $x, which is already installed."
        fi
    done
}

# Call a verb, don't let it affect environment
# Hope that subshell passes through exit status
# Usage: w_do_call foo [bar]       (calls load_foo bar)
# Or: w_do_call foo=bar            (also calls load_foo bar)
# Or: w_do_call foo                (calls load_foo)
w_do_call()
{
    (
        # Hack..
        if test $cmd = vd
        then
            load_vd $arg
            _W_status=$?
            test "$W_OPT_NOCLEAN" = 1 || rm -rf "$W_TMP"
            mkdir -p "$W_TMP"
            return $_W_status
        fi

        case $1 in
        *=*) arg=`echo $1 | sed 's/.*=//'`; cmd=`echo $1 | sed 's/=.*//'`;;
        *) cmd=$1; arg=$2 ;;
        esac

        # Kludge: use Temp instead of temp to avoid \t expansion in w_try
        # but use temp in Unix path because that's what Wine creates, and having both temp and Temp
        # causes confusion (e.g. makes vc2005trial fail)
        # FIXME: W_TMP is also set in winetricks_set_wineprefix, can we avoid the duplication?
        W_TMP="$W_DRIVE_C/windows/temp/_$1"
        W_TMP_WIN="C:\\windows\\Temp\\_$1"
        test "$W_OPT_NOCLEAN" = 1 || rm -rf "$W_TMP"
        mkdir -p "$W_TMP"

        # Unset all known used metadata values, in case this is a nested call
        unset conflicts installed_file1 installed_exe1

        if winetricks_metadata_exists $1
        then
            . "$WINETRICKS_METADATA"/*/$1.vars
        elif winetricks_metadata_exists $cmd
        then
            . "$WINETRICKS_METADATA"/*/$cmd.vars
        elif test $cmd = native || test $cmd = disabled || test $cmd = builtin || test $cmd = default
        then
            # ugly special case - can't have metadata for these verbs until we allow arbitrary parameters
            w_override_dlls $cmd $arg
            _W_status=$?
            test "$W_OPT_NOCLEAN" = 1 || rm -rf "$W_TMP"
            mkdir -p "$W_TMP"
            return $_W_status
        else
            w_die "No such verb $1"
        fi

        # If needed, set the app's wineprefix
        case "$OS" in
        Windows_NT)
            ;;
        *)
            case "$category"-"$WINETRICKS_OPT_SHAREDPREFIX" in
            apps-0|benchmarks-0|games-0)
                winetricks_set_wineprefix "$cmd"
                # If it's a new wineprefix, give it metadata
                if test ! -f "$WINEPREFIX"/wrapper.cfg
                then
                    echo ww_name=\"$title\" > "$WINEPREFIX"/wrapper.cfg
                fi
                ;;
            esac
            ;;
        esac

        test "$W_OPT_NOCLEAN" = 1 || rm -rf "$W_TMP"
        mkdir -p "$W_TMP"

        # Don't install if already installed
        if test "$WINETRICKS_FORCE" != 1 && winetricks_is_installed $1
        then
            echo "$1 already installed, skipping"
            return 0
        fi

        # Don't install if a conflicting verb is already installed:
        if test "$WINETRICKS_FORCE" != 1 && test "$conflicts" && test -f "$WINEPREFIX/winetricks.log"
        then
            for x in $conflicts
            do
                w_conflicts $1 $x
            done
        fi

        # We'd like to get rid of W_PACKAGE, but for now, just set it as late as possible.
        W_PACKAGE=$1
        w_try load_$cmd $arg
        winetricks_stats_log_command $*

        # User-specific postinstall hook.
        # Source it so the script can call w_download() if needed.
        postfile="$WINETRICKS_POST/$1/$1-postinstall.sh"
        if test -f "$postfile"
        then
            chmod +x "$postfile"
            . "$postfile"
        fi

        # Verify install
        if test "$installed_exe1" || test "$installed_file1"
        then
            if ! winetricks_is_installed $1
            then
                w_die "$1 install completed, but installed file $_W_file_unix not found"
            fi
        fi

        # If the user specified --verify, also run GUI tests:
        if test "$WINETRICKS_VERIFY" = 1 && type verify_$cmd 2> /dev/null
        then
            w_try verify_$cmd
        fi

        # Clean up after this verb
        test "$W_OPT_NOCLEAN" = 1 || rm -rf "$W_TMP"
        mkdir -p "$W_TMP"

        # Calling subshell must explicitly propagate error code with exit $?
    ) || exit $?
}

# If you want to check exit status yourself, use w_do_call
w_call()
{
    w_try w_do_call $@
}

w_register_font()
{
    file=$1
    shift
    font=$1

    case "$file" in
    *.TTF|*.ttf) font="$font (TrueType)";;
    esac

    # Kludge: use _r to avoid \r expansion in w_try
    cat > "$W_TMP"/_register-font.reg <<_EOF_
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Fonts]
"$font"="$file"
_EOF_
    # too verbose
    w_try_regedit "$W_TMP_WIN"\\_register-font.reg
    cp "$W_TMP"/*.reg "$W_TMP_EARLY"/_reg$$.reg

    # Wine also updates the win9x fonts key, so let's do that, too
    cat > "$W_TMP"/_register-font.reg <<_EOF_
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Fonts]
"$font"="$file"
_EOF_
    w_try_regedit "$W_TMP_WIN"\\_register-font.reg
    cp "$W_TMP"/*.reg "$W_TMP_EARLY"/_reg$$-2.reg
}

w_register_font_replacement()
{
    _W_alias=$1
    shift
    _W_font=$1
    # Kludge: use _r to avoid \r expansion in w_try
    cat > "$W_TMP"/_register-font-replacements.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\Fonts\Replacements]
"$_W_alias"="$_W_font"
_EOF_
    w_try_regedit "$W_TMP_WIN"\\_register-font-replacements.reg
    unset _W_alias _W_font
}

w_append_path()
{
    # Prepend $1 to the Windows path in the registry.
    # Use printf %s to avoid interpreting backslashes.
    _W_NEW_PATH="`printf %s $1| sed 's,\\\\,\\\\\\\\,g'`"
    _W_WIN_PATH="`w_expand_env PATH | sed 's,\\\\,\\\\\\\\,g'`"

    sed 's/$/\r/' > "$W_TMP"/path.reg <<_EOF_
REGEDIT4

[HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Session Manager\\Environment]
"PATH"="$_W_NEW_PATH;$_W_WIN_PATH"
_EOF_

    w_try_regedit "$W_TMP_WIN"\\path.reg
    rm -f "$W_TMP"/path.reg
    unset _W_NEW_PATH _W_WIN_PATH
}

#---- Private Functions ----

winetricks_get_sha1sum_prog() {
    # Mac folks tend to not have sha1sum, but we can make do with openssl
    if [ -x "`which sha1sum 2>/dev/null`" ]
    then
        WINETRICKS_SHA1SUM="sha1sum"
    elif [ -x "`which openssl 2>/dev/null`" ]
    then
        WINETRICKS_SHA1SUM="openssl dgst -sha1"
    else
        w_die "No sha1sum utility available."
    fi
}

winetricks_print_version() {
    # Normally done by winetricks_init, but we don't want to set up the WINEPREFIX
    # just to get the winetricks version:
    winetricks_get_sha1sum_prog

    w_get_sha1sum $0
    echo "$WINETRICKS_VERSION - sha1sum: $_W_gotsum"
}

# Run a small wine command for internal use
# Handy place to put small workarounds
winetricks_early_wine()
{
    # The sed works around http://bugs.winehq.org/show_bug.cgi?id=25838
    # which unfortunately got released in wine-1.3.12
    # We would like to use DISPLAY= to prevent virtual desktops from
    # popping up, but that causes AutoHotKey's tray icon to not show up.
    # We used to use WINEDLLOVERRIDES=mshtml= here to suppress the Gecko
    # autoinstall, but that yielded wineprefixes that *never* autoinstalled
    # Gecko (winezeug bug 223).
    # The tr removes carriage returns so expanded variables don't have crud on the end
    # The grep works around using new wineprefixes with old wine
    WINEDEBUG=-all "$WINE" "$@" 2> "$W_TMP_EARLY"/early_wine.err.txt | ( sed 's/.*1h.=//' | tr -d '\r' | grep -v "Module not found" || true)
}

winetricks_detect_gui()
{
    if test -x "`which zenity 2>/dev/null`"
    then
        WINETRICKS_GUI=zenity

        WINETRICKS_MENU_HEIGHT=500
        WINETRICKS_MENU_WIDTH=1010
    elif test -x "`which kdialog 2>/dev/null`"
    then
        echo "Zenity not found!  Using kdialog as poor substitute."
        WINETRICKS_GUI=kdialog
    else
        echo "No arguments given, so tried to start GUI, but zenity not found."
        echo "Please install zenity if you want a graphical interface, or "
        echo "run with --help for more options."
        exit 1
    fi
}

# Detect which sudo to use
winetricks_detect_sudo()
{
    WINETRICKS_SUDO=sudo
    if test "$WINETRICKS_GUI" = "none"
    then
        return
    fi
    if test x"$DISPLAY" != x""
    then
        if test -x "`which gksudo 2>/dev/null`"
        then
            WINETRICKS_SUDO=gksudo
        elif test -x "`which kdesudo 2>/dev/null`"
        then
            WINETRICKS_SUDO=kdesudo
        # fall back to the su versions if sudo isn't available (Fedora, etc.):
        elif test -x "`which gksu 2>/dev/null`"
        then
            WINETRICKS_SUDO=gksu
        elif test -x "`which kdesu 2>/dev/null`"
        then
            WINETRICKS_SUDO=kdesu
        fi
    fi
}

winetricks_get_prefix_var()
{
    (
        . "$W_PREFIXES_ROOT/$p/wrapper.cfg"
        # The cryptic sed is there to turn ' into '\''
        eval echo \$ww_$1 | sed "s/'/'\\\''/"
    )
}

# Display prefix menu, get which wineprefix the user wants to work with
winetricks_prefixmenu()
{
    case $LANG in
    ru*) _W_msg_title="Winetricks - выберите путь wine (wineprefix)"
         _W_msg_body='Что вы хотите сделать?'
         _W_msg_apps='Установить программу'
         _W_msg_games='Установить игру'
         _W_msg_benchmarks='Установить приложение для оценки производительности'
         _W_msg_default="Выберите путь для wine по умолчанию"
         _W_msg_unattended0="Отключить автоматическую установку"
         _W_msg_unattended1="Включить автоматическую установку"
         _W_msg_showbroken0="Спрятать нерабочие программы (например, использующие DRM)"
         _W_msg_showbroken1="Отобразить нерабочие программы (например, использующие DRM)"
         _W_msg_help="Просмотр справки (в веб браузере)"
         ;;
    uk*) _W_msg_title="Winetricks - виберіть wineprefix"
         _W_msg_body='Що Ви хочете зробити?'
         _W_msg_apps='Встановити додаток'
         _W_msg_games='Встановити гру'
         _W_msg_benchmarks='Встановити benchmark'
         _W_msg_default="Вибрати wineprefix за замовчуванням"
         _W_msg_unattended0="Вимкнути автоматичну установку"
         _W_msg_unattended1="Включити автоматичну установку"
         _W_msg_showbroken0="Сховати нестабільні додатки (наприклад з проблемами з DRM)"
         _W_msg_showbroken1="Показати нестабільні додатки (наприклад з проблемами з DRM)"
         _W_msg_help="Переглянути довідку"
         ;;
    zh_CN*)   _W_msg_title="Windows 应用安装向导 - 选择一个 wine 容器"
         _W_msg_body='君欲何为？'
         _W_msg_apps='安装一个 windows 应用'
         _W_msg_games='安装一个游戏'
         _W_msg_benchmarks='安装一个基准测试软件'
         _W_msg_default="选择默认的 wine 容器"
         _W_msg_unattended0="禁用静默安装"
         _W_msg_unattended1="启用静默安装"
         _W_msg_showbroken0="隐藏有问题的程序 (例如那些有数字版权问题)"
         _W_msg_showbroken1="有问题的程序 (例如那些有数字版权问题)"
         _W_msg_help="查看帮助"
         ;;
    zh_TW*|zh_HK*)   _W_msg_title="Windows 應用安裝向導 - 選取一個 wine 容器"
         _W_msg_body='君欲何為？'
         _W_msg_apps='安裝一個 windows 應用'
         _W_msg_games='安裝一個游戲'
         _W_msg_benchmarks='安裝一個基准測試軟體'
         _W_msg_default="選取預設的 wine 容器"
         _W_msg_unattended0="禁用靜默安裝"
         _W_msg_unattended1="啟用靜默安裝"
         _W_msg_showbroken0="隱藏有問題的程式 (例如那些有數字版權問題)"
         _W_msg_showbroken1="有問題的程式 (例如那些有數字版權問題)"
         _W_msg_help="檢視輔助說明"
         ;;
    de*) _W_msg_title="Winetricks - wineprefix auswählen"
         _W_msg_body='Was möchten Sie tun?'
         _W_msg_apps='Eine Programm installieren'
         _W_msg_games='Ein Spiel installieren'
         _W_msg_benchmarks='Ein Benchmark installieren'
         _W_msg_default="Standard wineprefix auswählen"
         _W_msg_unattended0="Automatische Installation deaktivieren"
         _W_msg_unattended1="Automatische Installation aktivieren"
         _W_msg_showbroken0="Defekte Programme nicht anzeigen (z.B. solche mit DRM Problemen)"
         _W_msg_showbroken1="Defekte Programme anzeigen (z.B. solche mit DRM Problemen)"
         _W_msg_help="Hilfe anzeigen"
         ;;
    *)   _W_msg_title="Winetricks - choose a wineprefix"
         _W_msg_body='What do you want to do?'
         _W_msg_apps='Install an application'
         _W_msg_games='Install a game'
         _W_msg_benchmarks='Install a benchmark'
         _W_msg_default="Select the default wineprefix"
         _W_msg_unattended0="Disable silent install"
         _W_msg_unattended1="Enable silent install"
         _W_msg_showbroken0="Hide broken apps (e.g. those with DRM problems)"
         _W_msg_showbroken1="Show broken apps (e.g. those with DRM problems)"
         _W_msg_help="View help"
         ;;
    esac
    case "$W_OPT_UNATTENDED" in
    1) _W_cmd_unattended=attended; _W_msg_unattended="$_W_msg_unattended0" ;;
    *) _W_cmd_unattended=unattended; _W_msg_unattended="$_W_msg_unattended1" ;;
    esac
    case "$W_OPT_SHOWBROKEN" in
    1) _W_cmd_showbroken=hidebroken; _W_msg_showbroken="$_W_msg_showbroken0" ;;
    *) _W_cmd_showbroken=showbroken; _W_msg_showbroken="$_W_msg_showbroken1" ;;
    esac

    case $WINETRICKS_GUI in
    zenity)
        printf %s "zenity \
            --title '$_W_msg_title' \
            --text '$_W_msg_body' \
            --list \
            --radiolist \
            --column '' \
            --column '' \
            --column '' \
            --height $WINETRICKS_MENU_HEIGHT \
            --width $WINETRICKS_MENU_WIDTH \
            --hide-column 2 \
            FALSE help       '$_W_msg_help' \
            FALSE apps       '$_W_msg_apps' \
            FALSE benchmarks '$_W_msg_benchmarks' \
            FALSE games      '$_W_msg_games' \
            TRUE  main       '$_W_msg_default' \
            " \
            > "$WINETRICKS_WORKDIR"/zenity.sh

        if ls -d $W_PREFIXES_ROOT/*/dosdevices > /dev/null 2>&1
        then
            for prefix in "$W_PREFIXES_ROOT"/*/dosdevices
            do
                q="${prefix%%/dosdevices}"
                p="${q##*/}"
                if test -f "$W_PREFIXES_ROOT/$p/wrapper.cfg"
                then
                    _W_msg_name="$p (`winetricks_get_prefix_var name`)"
                else
                    _W_msg_name="$p"
                fi
            case $LANG in 
            zh_CN*) printf %s " FALSE prefix='$p' '选择管理 $_W_msg_name' " ;;
            zh_TW*|zh_HK*) printf %s " FALSE prefix='$p' '選擇管理 $_W_msg_name' " ;;
            de*) printf %s " FALSE prefix='$p' '$_W_msg_name auswählen' " ;;
            *) printf %s " FALSE prefix='$p' 'Select $_W_msg_name' " ;;
            esac
            done >> "$WINETRICKS_WORKDIR"/zenity.sh
        fi
        printf %s " FALSE $_W_cmd_unattended '$_W_msg_unattended'" >> "$WINETRICKS_WORKDIR"/zenity.sh
        printf %s " FALSE $_W_cmd_showbroken '$_W_msg_showbroken'" >> "$WINETRICKS_WORKDIR"/zenity.sh

        sh "$WINETRICKS_WORKDIR"/zenity.sh | tr '|' ' '
        ;;

    kdialog)
        (
        printf %s "kdialog \
            --geometry 600x400+100+100 \
            --title '$_W_msg_title' \
            --separate-output \
            --radiolist '$_W_msg_body' \
            help       '$_W_msg_help'       off \
            games      '$_W_msg_games'      off \
            benchmarks '$_W_msg_benchmarks' off \
            apps       '$_W_msg_apps'       off \
            main       '$_W_msg_default'    on "
        if ls -d "$W_PREFIXES_ROOT"/*/dosdevices > /dev/null 2>&1
        then
            for prefix in "$W_PREFIXES_ROOT"/*/dosdevices
            do
                q="${prefix%%/dosdevices}"
                p="${q##*/}"
                if test -f "$W_PREFIXES_ROOT/$p/wrapper.cfg"
                then
                    _W_msg_name="$p (`winetricks_get_prefix_var name`)"
                else
                    _W_msg_name="$p"
                fi
                printf %s "prefix='$p' 'Select $_W_msg_name' off "
            done
        fi
        ) > "$WINETRICKS_WORKDIR"/kdialog.sh
        sh "$WINETRICKS_WORKDIR"/kdialog.sh
        ;;
    esac
    unset _W_msg_help _W_msg_body _W_msg_title _W_msg_new _W_msg_default _W_msg_name
}

# Display main menu, get which submenu the user wants
winetricks_mainmenu()
{
    case $LANG in
    da*) _W_msg_title='Vælg en pakke-kategori'
         _W_msg_body='Hvad ønsker du at gøre?'
         _W_msg_dlls="Install a Windows DLL"
         _W_msg_fonts='Install a font'
         _W_msg_settings='Change Wine settings'
         _W_msg_winecfg='Run winecfg'
         _W_msg_regedit='Run regedit'
         _W_msg_taskmgr='Run taskmgr'
         _W_msg_uninstaller='Run uninstaller'
         _W_msg_shell='Run a commandline shell (for debugging)'
         _W_msg_folder='Browse files'
         _W_msg_annihilate="Delete ALL DATA AND APPLICATIONS INSIDE THIS WINEPREFIX"
         ;;
    de*) _W_msg_title='Pakettyp auswählen'
         _W_msg_body='Was möchten Sie tun?'
         _W_msg_dlls="Windows-DLL installieren"
         _W_msg_fonts='Schriftart installieren'
         _W_msg_settings='Wine Einstellungen ändern'
         _W_msg_winecfg='winecfg starten'
         _W_msg_regedit='regedit starten'
         _W_msg_taskmgr='taskmgr starten'
         _W_msg_uninstaller='uninstaller starten'
         _W_msg_shell='Eine Kommandozeile zum debuggen starten'
         _W_msg_folder='Ordner durchsuchen'
         _W_msg_annihilate="ALLE DATEIEN UND PROGRAMME IN DIESEM WINEPREFIX Löschen"
         ;;
    pl*) _W_msg_title="Winetricks - obecny prefiks to \"$WINEPREFIX\""
         _W_msg_body='What would you like to do to this wineprefix?'
         _W_msg_dlls="Zainstaluj Windowsową bibliotekę DLL lub komponent"
         _W_msg_fonts='Zainstaluj czcionkę'
         _W_msg_settings='Zmień ustawienia'
         _W_msg_winecfg='Uruchom winecfg'
         _W_msg_regedit='Uruchom regedit'
         _W_msg_taskmgr='Uruchom taskmgr'
         _W_msg_uninstaller='Run uninstaller'
         _W_msg_shell='Uruchom powłokę wiersza poleceń (dla debugowania)'
         _W_msg_folder='Przeglądaj pliki'
         _W_msg_annihilate="Usuń WSZYSTKIE DANE I APLIKACJE WEWNĄTRZ TEGO WINEPREFIXA"
         ;;
    ru*) _W_msg_title="Winetricks - текущий путь для wine (wineprefix) \"$WINEPREFIX\""
         _W_msg_body='Что вы хотите сделать с этим wineprefix?'
         _W_msg_dlls="Установить DLL библиотеку или компонент Windows"
         _W_msg_fonts='Установить шрифт'
         _W_msg_settings='Поменять настройки'
         _W_msg_winecfg='Запустить winecfg (редактор настроек wine)'
         _W_msg_regedit='Запустить regedit (редактор рееста)'
         _W_msg_taskmgr='Запустить taskmgr (менеджер задач)'
         _W_msg_uninstaller='Запустить uninstaller (деинсталятор)'
         _W_msg_shell='Запустить графический терминал (для отладки)'
         _W_msg_folder='Проводник файлов'
         _W_msg_annihilate="Удалить ВСЕ ДАННЫЕ И ПРИЛОЖЕНИЯ В ЭТОМ WINEPREFIX"
         ;;
    uk*) _W_msg_title="Winetricks - поточний prefix \"$WINEPREFIX\""
         _W_msg_body='Що Ви хочете зробити для цього wineprefix?'
         _W_msg_dlls="Встановити Windows DLL чи компонент(и)"
         _W_msg_fonts='Встановити шрифт'
         _W_msg_settings='Змінити налаштування'
         _W_msg_winecfg='Запустити winecfg'
         _W_msg_regedit='Запустити regedit'
         _W_msg_taskmgr='Запустити taskmgr'
         _W_msg_uninstaller='Встановлення/видалення програм'
         _W_msg_shell='Запуск командної оболонки (для налагодження)'
         _W_msg_folder='Перегляд файлів'
         _W_msg_annihilate="Видалити УСІ ДАНІ ТА ПРОГРАМИ З ЦЬОГО WINEPREFIX"
         ;;
    zh_CN*)   _W_msg_title="Windows 应用安装向导 - 当前容器路径是 \"$WINEPREFIX\""
         _W_msg_body='管理当前容器'
         _W_msg_dlls="安装 Windows DLL 或组件"
         _W_msg_fonts='安装字体'
         _W_msg_settings='修改设置'
         _W_msg_winecfg='运行 winecfg'
         _W_msg_regedit='运行注册表'
         _W_msg_taskmgr='运行任务管理器'
         _W_msg_uninstaller='运行卸载程序'
         _W_msg_shell='运行命令提示窗口 (作为调试)'
         _W_msg_folder='浏览容器中的文件'
         _W_msg_annihilate="删除当前容器所有相关文件，包括启动器，完全卸载"
         ;;
    zh_TW*|zh_HK*)   _W_msg_title="Windows 應用裝載向導 - 目前容器路徑是 \"$WINEPREFIX\""
         _W_msg_body='管理目前容器'
         _W_msg_dlls="裝載 Windows DLL 或套件"
         _W_msg_fonts='裝載字型'
         _W_msg_settings='修改設定'
         _W_msg_winecfg='執行 winecfg'
         _W_msg_regedit='執行註冊表'
         _W_msg_taskmgr='執行工作管理者'
         _W_msg_uninstaller='執行反安裝程式'
         _W_msg_shell='執行指令輔助說明視窗 (作為除錯)'
         _W_msg_folder='瀏覽容器中的檔案'
         _W_msg_annihilate="移除目前容器所有相依檔案，包括啟動器，完全卸載"
         ;;
    *)   _W_msg_title="Winetricks - current prefix is \"$WINEPREFIX\""
         _W_msg_body='What would you like to do to this wineprefix?'
         _W_msg_dlls="Install a Windows DLL or component"
         _W_msg_fonts='Install a font'
         _W_msg_settings='Change settings'
         _W_msg_winecfg='Run winecfg'
         _W_msg_regedit='Run regedit'
         _W_msg_taskmgr='Run taskmgr'
         _W_msg_uninstaller='Run uninstaller'
         _W_msg_shell='Run a commandline shell (for debugging)'
         _W_msg_folder='Browse files'
         _W_msg_annihilate="Delete ALL DATA AND APPLICATIONS INSIDE THIS WINEPREFIX"
         ;;
    esac

    case $WINETRICKS_GUI in
    zenity)
        (
          printf %s "zenity \
            --title '$_W_msg_title' \
            --text '$_W_msg_body' \
            --list \
            --radiolist \
            --column '' \
            --column '' \
            --column '' \
            --height $WINETRICKS_MENU_HEIGHT \
            --width $WINETRICKS_MENU_WIDTH \
            --hide-column 2 \
            FALSE dlls        '$_W_msg_dlls' \
            FALSE fonts       '$_W_msg_fonts' \
            FALSE settings    '$_W_msg_settings' \
            FALSE winecfg     '$_W_msg_winecfg' \
            FALSE regedit     '$_W_msg_regedit' \
            FALSE taskmgr     '$_W_msg_taskmgr' \
            FALSE uninstaller '$_W_msg_uninstaller' \
            FALSE shell       '$_W_msg_shell' \
            FALSE folder      '$_W_msg_folder' \
            FALSE annihilate  '$_W_msg_annihilate' \
         "
         ) > "$WINETRICKS_WORKDIR"/zenity.sh
        sh "$WINETRICKS_WORKDIR"/zenity.sh | tr '|' ' '
        ;;

    kdialog)
        $WINETRICKS_GUI --geometry 600x400+100+100 \
                --title "$_W_msg_title" \
                --separate-output \
                --radiolist \
                "$_W_msg_body"\
                dlls        "$_W_msg_dlls" off \
                fonts       "$_W_msg_fonts" off \
                settings    "$_W_msg_settings" off \
                winecfg     "$_W_msg_winecfg" off \
                regedit     "$_W_msg_regedit" off \
                taskmgr     "$_W_msg_taskmgr" off \
                uninstaller "$_W_msg_uninstaller" off \
                shell       "$_W_msg_shell" off \
                folder      "$_W_msg_folder" off \
                annihilate  "$_W_msg_annihilate" off \
                $_W_cmd_unattended "$_W_msg_unattended" off \

        ;;
    esac
    unset _W_msg_body _W_msg_title _W_msg_apps _W_msg_benchmarks _W_msg_dlls _W_msg_games _W_msg_settings
}

winetricks_settings_menu()
{
    # FIXME: these translations should really be centralized/reused:
    case $LANG in
    da*) _W_msg_title='Vælg en pakke'
         _W_msg_body='Which settings would you like to change?'
         ;;
    de*) _W_msg_title="Winetricks - Aktueller Prefix ist \"$WINEPREFIX\""
         _W_msg_body='Welche Einstellungen möchten Sie ändern?'
         ;;
    pl*) _W_msg_title="Winetricks - obecny prefiks to \"$WINEPREFIX\""
         _W_msg_body='Which settings would you like to change?'
         ;;
    ru*) _W_msg_title="Winetricks - текущий путь wine (wineprefix) \"$WINEPREFIX\""
         _W_msg_body='Какие настройки вы хотите изменить?'
         ;;
    uk*) _W_msg_title="Winetricks - поточний prefix \"$WINEPREFIX\""
         _W_msg_body='Які налаштування Ви хочете змінити?'
         ;;
    zh_CN*)   _W_msg_title="Windows 应用安装向导 - 当前容器路径是 \"$WINEPREFIX\""
         _W_msg_body='君欲更改哪项设置？'
         ;;
    zh_TW*|zh_HK*)   _W_msg_title="Windows 應用裝載向導 - 目前容器路徑是 \"$WINEPREFIX\""
         _W_msg_body='君欲變更哪項設定？'
         ;;
    *)   _W_msg_title="Winetricks - current prefix is \"$WINEPREFIX\""
         _W_msg_body='Which settings would you like to change?'
         ;;
    esac

    case $WINETRICKS_GUI in
    zenity)
        case $LANG in
        da*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column Pakke \
                --column Navn \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
            ;;
        de*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column Einstellung \
                --column Name \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
            ;;
        pl*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column Ustawienie \
                --column Nazwa \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
            ;;
        ru*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column Установка \
                --column Имя \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
            ;;
        uk*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column Установка \
                --column Назва \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
            ;;
        zh_CN*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column 设置 \
                --column 标题 \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
            ;;
        zh_TW*|zh_HK*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column 設定 \
                --column 標題 \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
            ;;
        *) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column Setting \
                --column Title \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
            ;;
        esac > "$WINETRICKS_WORKDIR"/zenity.sh

        for metadatafile in "$WINETRICKS_METADATA"/$WINETRICKS_CURMENU/*.vars
        do
            code=`winetricks_metadata_basename "$metadatafile"`
            (
            title='?'
            author='?'
            . "$metadatafile"
          # Begin 'title' strings localization code
            case $LANG in
            uk*) case "$title_uk" in
                 "") ;;
                 *) title="$title_uk";;
                 esac
            esac
          # End of code
            printf "%s %s %s %s" " " FALSE \
                    $code \
                    "\"$title\""
            )
        done >> "$WINETRICKS_WORKDIR"/zenity.sh

        sh "$WINETRICKS_WORKDIR"/zenity.sh | tr '|' ' '
        ;;

    kdialog)
        (
        printf %s "kdialog --geometry 600x400+100+100 --title '$_W_msg_title' --separate-output --checklist '$_W_msg_body' "
        winetricks_list_all | sed 's/\([^ ]*\)  *\(.*\)/\1 "\1 - \2" off /' | tr '\012' ' '
        ) > "$WINETRICKS_WORKDIR"/kdialog.sh
        sh "$WINETRICKS_WORKDIR"/kdialog.sh
        ;;
    esac

    unset _W_msg_body _W_msg_title
}

# Display the current menu, output list of verbs to execute to stdout
winetricks_showmenu()
{
    case $LANG in
    da*) _W_msg_title='Vælg en pakke'
         _W_msg_body='Vilken pakke vil du installere?'
         _W_cached="cached"
         ;;
    de*) _W_msg_title="Winetricks - Aktueller Prefix ist \"$WINEPREFIX\""
         _W_msg_body='Welche Paket(e) möchten Sie installieren?'
         _W_cached="gecached"
         ;;
    pl*) _W_msg_title="Winetricks - obecny prefiks to \"$WINEPREFIX\""
         _W_msg_body='Które paczki chesz zainstalować?'
         _W_cached="zarchiwizowane"
         ;;
    ru*) _W_msg_title="Winetricks - текущий путь wine (wineprefix) \"$WINEPREFIX\""
         _W_msg_body='Какое приложение(я) вы хотите установить?'
         _W_cached="в кэше"
         ;;
    uk*) _W_msg_title="Winetricks - поточний prefix \"$WINEPREFIX\""
         _W_msg_body='Які пакунки Ви хочете встановити?'
         _W_cached="кешовано"
         ;;
    zh_CN*)   _W_msg_title="Windows 应用安装向导 - 当前容器路径是 \"$WINEPREFIX\""
         _W_msg_body='君欲安装何种应用？'
         _W_cached="已缓存"
         ;;
    zh_TW*|zh_HK*)   _W_msg_title="Windows 應用裝載向導 - 目前容器路徑是 \"$WINEPREFIX\""
         _W_msg_body='君欲裝載何種應用？'
         _W_cached="已緩存"
         ;;
    *)   _W_msg_title="Winetricks - current prefix is \"$WINEPREFIX\""
         _W_msg_body='Which package(s) would you like to install?'
         _W_cached="cached"
         ;;
    esac


    case $WINETRICKS_GUI in
    zenity)
        case $LANG in
        da*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column Pakke \
                --column Navn \
                --column Udgiver \
                --column År \
                --column Medie \
                --column Status \
                --column 'Size (MB)' \
                --column 'Time (sec)' \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
            ;;
        de*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column Paket \
                --column Name \
                --column Herausgeber \
                --column Jahr \
                --column Media \
                --column Status \
                --column 'Größe (MB)' \
                --column 'Zeit (sec)' \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
             ;;
        pl*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column Paczka \
                --column Nazwa \
                --column Wydawca \
                --column Rok \
                --column Media \
                --column Status \
                --column 'Rozmiar (MB)' \
                --column 'Czas (sek)' \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
             ;;
        ru*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column Пакет \
                --column Название \
                --column Издатель \
                --column Год \
                --column Источник \
                --column Статус \
                --column 'Размер (МБ)' \
                --column 'Время (сек)' \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
             ;;
        uk*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column Пакунок \
                --column Назва \
                --column Видавець \
                --column Рік \
                --column Медіа \
                --column Статус \
                --column 'Розмір (МБ)' \
                --column 'Час (сек)' \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
             ;;
        zh_CN*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column 包名 \
                --column 软件名 \
                --column 发行商 \
                --column 发行年 \
                --column 媒介 \
                --column 状态 \
                --column '文件大小 (MB)' \
                --column '时间 (秒)' \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
             ;;
        zh_TW*|zh_HK*) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column 包名 \
                --column 軟體名 \
                --column 發行商 \
                --column 發行年 \
                --column 媒介 \
                --column 狀態 \
                --column '檔案大小 (MB)' \
                --column '時間 (秒)' \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
             ;;
        *) printf %s "zenity \
                --title '$_W_msg_title' \
                --text '$_W_msg_body' \
                --list \
                --checklist \
                --column '' \
                --column Package \
                --column Title \
                --column Publisher \
                --column Year \
                --column Media \
                --column Status \
                --column 'Size (MB)' \
                --column 'Time (sec)' \
                --height $WINETRICKS_MENU_HEIGHT \
                --width $WINETRICKS_MENU_WIDTH \
                "
             ;;
        esac > "$WINETRICKS_WORKDIR"/zenity.sh

        > "$WINETRICKS_WORKDIR"/installed.txt
        for metadatafile in "$WINETRICKS_METADATA"/$WINETRICKS_CURMENU/*.vars
        do
            code=`winetricks_metadata_basename "$metadatafile"`
            (
            title='?'
            author='?'
            . "$metadatafile"
            if test "$W_OPT_SHOWBROKEN" = 1 || test "$wine_showstoppers" = ""
            then
                # Compute cached and downloadable flags
                flags=""
                winetricks_is_cached $code && flags="$_W_cached"
                installed=FALSE
                if winetricks_is_installed $code
                then
                    installed=TRUE
                    echo $code >> "$WINETRICKS_WORKDIR"/installed.txt
                fi
                printf %s " $installed \
                    $code \
                    \"$title\" \
                    \"$publisher\" \
                    \"$year\" \
                    \"$media\" \
                    \"$flags\" \
                    \"$size_MB\" \
                    \"$time_sec\" \
                "
            fi
            )
        done >> "$WINETRICKS_WORKDIR"/zenity.sh

        # Filter out any verb that's already installed
        sh "$WINETRICKS_WORKDIR"/zenity.sh |
            tr '|' '\012' |
            fgrep -v -x -f "$WINETRICKS_WORKDIR"/installed.txt |
            tr '\012' ' '
        ;;

    kdialog)
        (
        printf %s "kdialog --geometry 600x400+100+100 --title '$_W_msg_title' --separate-output --checklist '$_W_msg_body' "
        winetricks_list_all | sed 's/\([^ ]*\)  *\(.*\)/\1 "\1 - \2" off /' | tr '\012' ' '
        ) > "$WINETRICKS_WORKDIR"/kdialog.sh
        sh "$WINETRICKS_WORKDIR"/kdialog.sh
        ;;
    esac

    unset _W_msg_body _W_msg_title
}

# Converts a metadata abolute path to its app code
winetricks_metadata_basename()
{
    # Classic, but too slow on cygwin
    #basename $1 .vars

    # first, remove suffix .vars
    _W_mb_tmp=${1%.vars}
    # second, remove any directory prefix
    echo ${_W_mb_tmp##*/}
    unset _W_mb_tmp
}

# Returns true if given verb has been registered
winetricks_metadata_exists()
{
    test -f "$WINETRICKS_METADATA"/*/$1.vars
}

# Returns true if given verb has been cached
# You must have already loaded its metadata before calling
winetricks_is_cached()
{
    # FIXME: also check file2... if given
    _W_path="$W_CACHE/$1/$file1"
    case "$_W_path" in
    *..*)
        # Remove /foo/.. so verbs that don't have their own cache directories
        # can refer to siblings
        _W_path="`echo $_W_path | sed 's,/[^/]*/\.\.,,'`"
        ;;
    esac
    if test -f "$_W_path"
    then
        unset _W_path
        return 0
    fi
    unset _W_path
    return 1
}

# Returns true if given verb has been installed
# You must have already loaded its metadata before calling
winetricks_is_installed()
{
    unset _W_file _W_file_unix
    if test "$installed_exe1"
    then
        _W_file="$installed_exe1"
    elif test "$installed_file1"
    then
        _W_file="$installed_file1"
    else
        return 1  # not installed
    fi

    case "$OS" in
    Windows_NT)
        # On Windows, there's no wineprefix, just check if file's there
        _W_file_unix="`w_pathconv -u "$_W_file"`"
        if test -f "$_W_file_unix"
        then
            unset _W_file _W_file_unix _W_prefix
            return 0  # installed
        fi
        ;;
    *)
        # Compute wineprefix for this app
        case "$category"-"$WINETRICKS_OPT_SHAREDPREFIX" in
        apps-0|benchmarks-0|games-0)
            _W_prefix="$W_PREFIXES_ROOT/$1"
            ;;
        *)
            _W_prefix="$WINEPREFIX"
            ;;
        esac
        if test -d "$_W_prefix/dosdevices"
        then
          # 'win7 vcrun2005' creates different file than 'winxp vcrun2005'
          # so let it specify multiple, separated by |
          _W_IFS="$IFS"
          IFS='|'
          for _W_file_ in $_W_file
          do
            _W_file_unix="`WINEPREFIX="$_W_prefix" w_pathconv -u "$_W_file_"`"
            if test -f "$_W_file_unix" && ! grep -q "Wine placeholder DLL" "$_W_file_unix"
            then
                IFS="$_W_IFS"
                unset _W_file _W_file_ _W_file_unix _W_prefix _W_IFS
                return 0  # installed
            fi
          done
         IFS="$_W_IFS"
        fi
        ;;
    esac
    unset _W_file _W_prefix  # leak _W_file_unix for caller.  Is this wise?
    unset _W_IFS _W_file_
    return 1  # not installed
}

# List verbs which are already fully cached locally
winetricks_list_cached()
{
    for _W_metadatafile in "$WINETRICKS_METADATA"/*/*.vars
    do
        # Use a subshell to avoid putting metadata in global space
        # If this is too slow, we can unset known metadata by hand
        (
        code=`winetricks_metadata_basename "$_W_metadatafile"`
        . "$_W_metadatafile"
        if winetricks_is_cached $code
        then
            echo $code
        fi
        )
    done | sort
    unset _W_metadatafile
}

# List verbs which are automatically downloadable, regardless of whether they're cached yet
winetricks_list_download()
{
    cd "$WINETRICKS_METADATA"
    grep -l 'media=.download' */*.vars | sed 's,.*/,,;s/\.vars//' | sort -u
}

# List verbs which are downloadable with user intervention, regardless of whether they're cached yet
winetricks_list_manual_download()
{
    cd "$WINETRICKS_METADATA"
    grep -l 'media=.manual_download' */*.vars | sed 's,.*/,,;s/\.vars//' | sort -u
}

winetricks_list_installed()
{
    (
    # Jump through a couple hoops to evaluate the verbs in alphabetical order
    # Assume that no filename contains '|'
    cd "$WINETRICKS_METADATA"
    for _W_metadatafile in `ls */*.vars | sed 's,^\(.*\)/,\1|,' | sort -t\| -k 2 | tr '|' /`
    do
        # Use a subshell to avoid putting metadata in global space
        # If this is too slow, we can unset known metadata by hand
        (
        code=`winetricks_metadata_basename "$_W_metadatafile"`
        . "$_W_metadatafile"
        if winetricks_is_installed $code
        then
            echo $code
        fi
        )
    done
    )
    unset _W_metadatafile
}

# Helper for adding a string to a list of flags
winetricks_append_to_flags()
{
    if test "$flags"
    then
        flags="$flags,"
    fi
    flags="${flags}$1"
}

# List all verbs in category WINETRICKS_CURMENU verbosely
# Format is "verb  title  (publisher, year) [flags]"
winetricks_list_all()
{
    # Note: doh123 relies on 'winetricks list' to list main menu categories
    case $WINETRICKS_CURMENU in
    prefix|main) echo "$WINETRICKS_CATEGORIES" | tr ' ' '\012' ; return;;
    esac

    case $LANG in
    da*) _W_cached="cached"   ; _W_download="kan hentes"    ;;
    de*) _W_cached="gecached" ; _W_download="herunterladbar";;
    pl*) _W_cached="zarchiwizowane"   ; _W_download="do pobrania"  ;;
    ru*) _W_cached="в кэше"   ; _W_download="доступно для скачивания"  ;;
    uk*) _W_cached="кешовано"   ; _W_download="завантажуване"  ;;
    zh_CN*)   _W_cached="已缓存"   ; _W_download="可下载"  ;;
    zh_TW*|zh_HK*)   _W_cached="已緩存"   ; _W_download="可下載"  ;;
    *)   _W_cached="cached"   ; _W_download="downloadable"  ;;
    esac

    for _W_metadatafile in "$WINETRICKS_METADATA"/$WINETRICKS_CURMENU/*.vars
    do
        # Use a subshell to avoid putting metadata in global space
        # If this is too slow, we can unset known metadata by hand
        (
        code=`winetricks_metadata_basename "$_W_metadatafile"`
        . "$_W_metadatafile"

        # Compute cached and downloadable flags
        flags=""
        test "$media" = "download" && winetricks_append_to_flags "$_W_download"
        winetricks_is_cached $code   && winetricks_append_to_flags "$_W_cached"
        test "$flags" && flags="[$flags]"

        if ! test "$year" && ! test "$publisher"
        then
            printf "%-24s %s %s\n" $code "$title" "$flags"
        else
            printf "%-24s %s (%s, %s) %s\n" $code "$title" "$publisher" "$year" "$flags"
        fi
        )
    done
    unset _W_cached _W_metadatafile
}

# Abort if user doesn't own the given directory (or its parent, if it doesn't exist yet)
winetricks_die_if_user_not_dirowner()
{
    if test -d "$1"
    then
        _W_checkdir="$1"
    else
        # fixme: quoting problem?
        _W_checkdir=`dirname "$1"`
    fi
    _W_nuser=`id -u`
    _W_nowner=`ls -l -n -d -L "$_W_checkdir" | awk '{print $3}'`
    if test x$_W_nuser != x$_W_nowner
    then
        w_die "You (`id -un`) don't own $_W_checkdir.  Don't run this tool as another user!"
    fi
}

# See
# http://www.ecma-international.org/publications/files/ECMA-ST/Ecma-119.pdf (iso9660)
# http://www.ecma-international.org/publications/files/ECMA-ST/Ecma-167.pdf
# http://www.osta.org/specs/pdf/udf102.pdf
# http://www.ecma-international.org/publications/techreports/E-TR-071.htm

# Usage: read_bytes offset count device
winetricks_read_bytes()
{
    dd status=noxfer if=$3 bs=1 skip=$1 count=$2 2>/dev/null
}

# Usage: read_hex offset count device
winetricks_read_hex()
{
    od -j $1 -N $2 -t x1 $3          | # offset $1, count $2, single byte hex format, file $3
        sed 's/^[^ ]* //'             | # remove address
        sed '$d'                        # remove final line which is just final offset
}

# Usage: read_decimal offset device
# Reads single four byte word, outputs in decimal.
# Uses default endianness.
# udf uses little endian words, so this only works on little endian machines.
winetricks_read_decimal()
{
    od -j $1 -N 4  -t u4 $2          | # offset $1, byte count 4, four byte decimal format, file $2
        sed 's/^[^ ]* //'             | # remove address
        sed '$d'                        # remove final line which is just final offset
}

winetricks_read_udf_volume_name()
{
    # "Anchor volume descriptor pointer" starts at sector 256

    # AVDP Layout (ECMA-167 3/10.2):
    # size   offset   contents
    # 16     0        descriptor tag (id = 2)
    # 16     8        main (primary?) volume descriptor sequence extent
    # ...

    # descriptor tag layout (ECMA-167 3/7.2):
    # size   offset   contents
    # 2      0        TagIdentifier
    # ...

    # extent layout (ECMA-167 3/7.1):
    # size   offset   contents
    # 4      0        length (in bytes)
    # 8      4        location (in 2k sectors)

    # primary volume descriptor layout (ECMA-167 3/10.1):
    # size   offset   contents
    # 16     0        descriptor tag (id = 1)
    # ...
    # 32     24       volume identifier (dstring)

    # 1. check the 16 bit TagIdentifier of the descriptor tag, make sure it's 2
    tagid=`winetricks_read_hex 524288 2 $1`
    : echo tagid is $tagid
    case "$tagid" in
    "02 00") : echo Found AVDP ;;
    *) echo "Did not find AVDP (tagid was $tagid)"; exit 1;;
    esac

    # 2. read the location of the main volume descriptor:
    offset=`winetricks_read_decimal 524308 $1`
    : echo MVD is at sector $offset
    offset=`expr $offset \* 2048`
    : echo MVD is at byte $offset

    # 3. check the TagIdentifier of the MVD's descriptor tag, make sure it's 1
    tagid=`winetricks_read_hex $offset 2 $1`
    : echo tagid is $tagid
    case "$tagid" in
    "01 00") : echo Found MVD ;;
    *) echo Did not find MVD; exit 1;;
    esac

    # 4. Read whether the name is in 8 or 16 bit chars
    offset=`expr $offset + 24`
    width=`winetricks_read_hex $offset 1 $1`

    offset=`expr $offset + 1`

    # 5. Profit!
    case $width in
    08)   winetricks_read_bytes $offset 30 $1 | sed 's/  *$//' ;;
    10)  winetricks_read_bytes $offset 30 $1 | tr -d '\000' | sed 's/  *$//' ;;
    *) echo "Unhandled dvd volname character width '$width'"; exit 1;;
    esac

    echo ""
}

winetricks_read_iso9660_volume_name()
{
    winetricks_read_bytes 32808 30 $1 | sed 's/  *$//'
}

winetricks_read_volume_name()
{
    # ECMA-119 says that CD-ROMs have sector size 2k, and at sector 16 have:
    # size  offset contents
    #  1    0      Volume descriptor type (1 for primary volume descriptor)
    #  5    1      Standard identifier ("CD001" for iso9660)
    # ECMA-167, section 9.1.2, has a table of standard identifiers:
    # "BEA01": ecma-167 9.2, Beginning Extended Area Descriptor
    # "CD001": ecma-119
    # "CDW02": ecma-168

    std_id=`winetricks_read_bytes 32769 5 $1`
    : echo std_id is $std_id

    case $std_id in
    CD001) winetricks_read_iso9660_volume_name $1 ;;
    BEA01) winetricks_read_udf_volume_name $1; ;;
    *) echo "Unrecognized disk type $std_id"; exit 1 ;;
    esac
}

winetricks_volname()
{
    x=`volname $1 2> /dev/null| sed 's/  *$//'`
    if test "x$x" = "x"
    then
        # UDF?  See https://bugs.launchpad.net/bugs/678419
        x=`winetricks_read_volume_name $1`
    fi
    echo $x
}

# Really, should take a volume name as argument, and use 'mount' to get
# mount point if system automounted it.
winetricks_detect_optical_drive()
{
    case "$WINETRICKS_DEV" in
    "") ;;
    *) return ;;
    esac

    for WINETRICKS_DEV in /dev/cdrom /dev/dvd /dev/sr0
    do
        test -b $WINETRICKS_DEV && break
    done

    case "$WINETRICKS_DEV" in
    "x") w_die "can't find cd/dvd drive" ;;
    esac
}

winetricks_cache_iso()
{
    # WINETRICKS_IMG has already been set by w_mount
    _W_expected_volname="$1"

    winetricks_die_if_user_not_dirowner "$W_CACHE"
    winetricks_detect_optical_drive

    # Horrible hack for Gentoo - make sure we can read from the drive
    if ! test -r $WINETRICKS_DEV
    then
        case "$WINETRICKS_SUDO" in
        gksudo) $WINETRICKS_SUDO "chmod 666 $WINETRICKS_DEV" ;;
        *) $WINETRICKS_SUDO chmod 666 $WINETRICKS_DEV ;;
        esac
    fi

    while true
    do
        # Wait for user to insert disc.
        # Sleep long to make it less likely to close the drive during insertion.
        while ! dd if=$WINETRICKS_DEV of=/dev/null count=1
        do
            sleep 5
        done

        # Some distributions automount discs in /media, take advantage of that
        if test -d "/media/_W_expected_volname"
        then
            break
        fi
        # Otherwise try and read it straight from unmounted volume
        _W_volname=`winetricks_volname $WINETRICKS_DEV`
        if test "$_W_expected_volname" != "$_W_volname"
        then
            case $LANG in
            da*)  w_warn "Forkert disk [$_W_volname] indsat. Indsæt venligst disken [$_W_expected_volname]" ;;
            de*)  w_warn "Falsche Disk [$_W_volname] eingelegt. Bitte legen Sie Disk [$_W_expected_volname] ein!" ;;
            pl*)  w_warn "Włożono zły dysk [$_W_volname]. Proszę włożyć dysk [$_W_expected_volname]" ;;
            ru*)  w_warn "Неверный диск [$_W_volname]. Пожалуйста, вставьте диск [$_W_expected_volname]" ;;
            uk*)  w_warn "Неправильний диск [$_W_volname]. Будь ласка, вставте диск [$_W_expected_volname]" ;;
            zh_CN*)    w_warn " [$_W_volname] 光盘插入错误，请插入光盘 [$_W_expected_volname]" ;;
            zh_TW*|zh_HK*)    w_warn " [$_W_volname] 光碟插入錯誤，請插入光碟 [$_W_expected_volname]" ;;
            *)    w_warn "Wrong disc [$_W_volname] inserted.  Please insert disc [$_W_expected_volname]" ;;
            esac

            sleep 10
        else
            break
        fi
    done

    # Copy disc to .iso file, display progress every 5 seconds
    # Use conv=noerror,sync to replace unreadable blocks with zeroes
    case $WINETRICKS_OPT_DD in
    dd)
      $WINETRICKS_OPT_DD if=$WINETRICKS_DEV of="$W_CACHE"/temp.iso bs=2048 conv=noerror,sync &
      WINETRICKS_DD_PID=$!
      ;;
    ddrescue)
      if test "`which ddrescue`" = ""
      then
          w_die "Please install ddrescue first."
      fi
      $WINETRICKS_OPT_DD -v -b 2048 $WINETRICKS_DEV "$W_CACHE"/temp.iso &
      WINETRICKS_DD_PID=$!
      ;;
    esac
    echo $WINETRICKS_DD_PID > "$WINETRICKS_WORKDIR"/dd-pid

    # Note: if user presses ^C, winetricks_cleanup will call winetricks_iso_cleanup
    # FIXME: add progress bar for kde, too
    case $WINETRICKS_GUI in
    none|kdialog)
        while ps -p $WINETRICKS_DD_PID > /dev/null 2>&1
        do
          sleep 5
          ls -l "$W_CACHE"/temp.iso
        done
        ;;
    zenity)
        while ps -p $WINETRICKS_DD_PID > /dev/null 2>&1
        do
          echo 1
          sleep 2
        done | $WINETRICKS_GUI --title "Copying to $_W_expected_volname.iso" --progress --pulsate --auto-kill
        ;;
    esac
    rm "$WINETRICKS_WORKDIR"/dd-pid

    mv "$W_CACHE"/temp.iso "$WINETRICKS_IMG"

    eject $WINETRICKS_DEV || true    # punt if eject not found (as on cygwin)
}

winetricks_load_vcdmount()
{
    if test "$WINE" != ""
    then
        return
    fi

    # Call only on real Windows.
    # Sets VCD_DIR and W_ISO_MOUNT_ROOT

    # The only free mount tool I know for Windows Vista is Virtual CloneDrive,
    # which can be downloaded at
    # http://www.slysoft.com/en/virtual-clonedrive.html
    # FIXME: actually install it here

    # Locate vcdmount.exe.
    VCD_DIR="Elaborate Bytes/VirtualCloneDrive"
    if test ! -x "$W_PROGRAMS_UNIX/$VCD_DIR/vcdmount.exe" && test ! -x "$W_PROGRAMS_X86_UNIX/$VCD_DIR/vcdmount.exe"
    then
        w_warn "Installing Virtual CloneDrive"
        w_download_to vcd http://static.slysoft.com/SetupVirtualCloneDrive.exe
        # have to use cmd else vista won't let cygwin run .exe's?
        chmod +x "$W_CACHE"/vcd/SetupVirtualCloneDrive.exe
        cd "$W_CACHE/vcd"
        cmd /c SetupVirtualCloneDrive.exe
    fi
    if test -x "$W_PROGRAMS_UNIX/$VCD_DIR/vcdmount.exe"
    then
        VCD_DIR="$W_PROGRAMS_UNIX/$VCD_DIR"
    elif test -x "$W_PROGRAMS_X86_UNIX/$VCD_DIR/vcdmount.exe"
    then
        VCD_DIR="$W_PROGRAMS_X86_UNIX/$VCD_DIR"
    else
        w_die "can't find Virtual CloneDrive?"
    fi
    # FIXME: Use WMI to locate the drive named
    # "ELBY CLONEDRIVE..." using WMI as described in
    # http://delphihaven.wordpress.com/2009/07/05/using-wmi-to-get-a-drive-friendly-name/
}

winetricks_mount_cached_iso()
{
    # On entry, WINETRICKS_IMG is already set
    w_umount

    if test "$WINE" = ""
    then
        winetricks_load_vcdmount
        my_img_win="`w_pathconv -w $WINETRICKS_IMG | tr '\012' ' ' | sed 's/ $//'`"
        cd "$VCD_DIR"
        w_try vcdmount.exe /l=$letter "$my_img_win"

        tries=0
        while test $tries -lt 20
        do
            for W_ISO_MOUNT_LETTER in e f g h i j k
            do
                # let user blacklist drive letters
                echo "$WINETRICKS_MOUNT_LETTER_IGNORE" | grep -q "$W_ISO_MOUNT_LETTER" && continue
                W_ISO_MOUNT_ROOT=/cygdrive/$W_ISO_MOUNT_LETTER
                if find $W_ISO_MOUNT_ROOT -iname 'setup*' -o -iname '*.exe' -o -iname '*.msi'
                then
                    break 2
                fi
            done
            tries=`expr $tries + 1`
            echo "Waiting for mount to finish mounting"
            sleep 1
        done
    else
        # Linux
        # FIXME: find a way to mount or copy from image without sudo
        _W_USERID=`id -u`
        case "$WINETRICKS_SUDO" in
        gksudo)
          w_try $WINETRICKS_SUDO "mkdir -p $W_ISO_MOUNT_ROOT"
          w_try $WINETRICKS_SUDO "mount -o ro,loop,uid=$_W_USERID,unhide $WINETRICKS_IMG $W_ISO_MOUNT_ROOT"
          ;;
        *)
          w_try $WINETRICKS_SUDO mkdir -p $W_ISO_MOUNT_ROOT
          w_try $WINETRICKS_SUDO mount -o ro,loop,uid=$_W_USERID,unhide "$WINETRICKS_IMG" $W_ISO_MOUNT_ROOT
          ;;
        esac

        echo "Mounting as drive ${W_ISO_MOUNT_LETTER}:"
        # Gotta provide a symlink to the raw disc, else installers that check volume names will fail
        rm -f "$WINEPREFIX/dosdevices/${W_ISO_MOUNT_LETTER}:"*
        ln -sf "$WINETRICKS_IMG" "$WINEPREFIX/dosdevices/${W_ISO_MOUNT_LETTER}::"
        ln -sf "$W_ISO_MOUNT_ROOT" "$WINEPREFIX/dosdevices/${W_ISO_MOUNT_LETTER}:"
        unset _W_USERID
    fi
}

# List the currently mounted UDF or iso9660 filesystems that match the given pattern
# Output format:
#   dev mountpoint
#   dev mountpoint
#   ...
# Mount points may contain spaces.

winetricks_list_mounts()
{
    mount | egrep 'udf|iso9660' | sed 's,^\([^ ]*\) on \(.*\) type .*,\1 \2,'| grep "$1\$"
}

# Return success and set _W_dev _W_mountpoint if volume $1 is mounted
# Note: setting variables as a way of returning results from a
# shell function exposed several bugs in most shells (except ksh!)
# related to implicit subshells.  It would be better to output
# one string to stdout instead.
winetricks_is_mounted()
{
    # First, check for matching mountpoint
    _W_tmp="`winetricks_list_mounts "$1"`"
    if test "$_W_tmp"
    then
        _W_dev=`echo $_W_tmp | sed 's/ .*//'`
        _W_mountpoint="`echo $_W_tmp | sed 's/^[^ ]* //'`"
        # Volume found!
        return 0
    fi

    # If that fails, read volume name the hard way for each volume
    # Have to use file to return results from implicit subshell
    rm -f "$W_TMP_EARLY/_W_tmp.$LOGNAME"
    winetricks_list_mounts . | while true
    do
        IFS= read _W_tmp

        _W_dev=`echo $_W_tmp | sed 's/ .*//'`
        test "$_W_dev" || break
        _W_mountpoint="`echo $_W_tmp | sed 's/^[^ ]* //'`"
        _W_volname=`winetricks_volname $_W_dev`
        if test "$1" = "$_W_volname"
        then
            # Volume found!  Want to return from function here, but can't
            echo "$_W_tmp" > "$W_TMP_EARLY/_W_tmp.$LOGNAME"
            break
        fi
    done

    if test -f "$W_TMP_EARLY/_W_tmp.$LOGNAME"
    then
        # Volume found!  Return from function.
        _W_dev=`cat "$W_TMP_EARLY/_W_tmp.$LOGNAME" | sed 's/ .*//'`
        _W_mountpoint="`cat "$W_TMP_EARLY/_W_tmp.$LOGNAME" | sed 's/^[^ ]* //'`"
        rm -f "$W_TMP_EARLY/_W_tmp.$LOGNAME"
        return 0
    fi

    # Volume not found
    unset _W_dev _W_mountpoint _W_volname
    return 1
}

winetricks_mount_real_volume()
{
    _W_expected_volname="$1"

    # Wait for user to insert disc.

    case $LANG in
    da*)_W_mountmsg="Indsæt venligst disken '$_W_expected_volname' (krævet af pakken '$_PACKAGE')" ;;
    de*)_W_mountmsg="Bitte Disk '$_W_expected_volname' einlegen (für Paket '$W_PACKAGE')" ;;
    pl*)  _W_mountmsg="Proszę włożyć dysk '$_W_expected_volname' (potrzebny paczce '$W_PACKAGE')" ;;
    ru*)  _W_mountmsg="Пожалуйста, вставьте том '$_W_expected_volname' (требуется для пакета '$W_PACKAGE')" ;;
    uk*)  _W_mountmsg="Будь ласка, вставте том '$_W_expected_volname' (потрібний для пакунка '$W_PACKAGE')" ;;
    zh_CN*)  _W_mountmsg="请插入卷 '$_W_expected_volname' (为包 '$W_PACKAGE 所需')" ;;
    zh_TW*|zh_HK*)  _W_mountmsg="請插入卷 '$_W_expected_volname' (為包 '$W_PACKAGE 所需')" ;;
    *)  _W_mountmsg="Please insert volume '$_W_expected_volname' (needed for package '$W_PACKAGE')" ;;
    esac

    if test "$WINE" = ""
    then
        # Assume already mounted, just get drive letter
        W_ISO_MOUNT_LETTER=`awk '/iso/ {print $1}' < /proc/mounts | tr -d :`
        W_ISO_MOUNT_ROOT=`awk '/iso/ {print $2}' < /proc/mounts`
    else
        while ! winetricks_is_mounted "$_W_expected_volname"
        do
            w_try w_warn_cancel "$_W_mountmsg"
            # In non-gui case, give user two seconds to futz with disc drive before spamming him again
            sleep 2
        done
        WINETRICKS_DEV=$_W_dev
        W_ISO_MOUNT_ROOT="$_W_mountpoint"

        # Gotta provide a symlink to the raw disc, else installers that check volume names will fail
        rm -f "$WINEPREFIX/dosdevices/${W_ISO_MOUNT_LETTER}:"*
        ln -sf "$WINETRICKS_DEV" "$WINEPREFIX/dosdevices/${W_ISO_MOUNT_LETTER}::"
        ln -sf "$W_ISO_MOUNT_ROOT" "$WINEPREFIX/dosdevices/${W_ISO_MOUNT_LETTER}:"
    fi

    # FIXME: need to remount some discs with unhide option,
    # add that as option to w_mount

    unset _W_mountmsg
}

winetricks_cleanup()
{
    # We don't want to run this multiple times, so unfortunately we have to run it here:
    if test "$W_NGEN_CMD"
    then
        "$W_NGEN_CMD"
    fi

    set +e
    if test -f "$WINETRICKS_WORKDIR/dd-pid"
    then
        kill `cat "$WINETRICKS_WORKDIR/dd-pid"`
    fi
    test "$WINETRICKS_CACHE_SYMLINK" && rm -f "$WINETRICKS_CACHE_SYMLINK"
    test "$W_OPT_NOCLEAN" = 1 || rm -rf "$WINETRICKS_WORKDIR"
    # if $W_TMP_EARLY was created by mktemp, remove it:
    test "$W_OPT_NOCLEAN" = 1 || test "$W_TMP_EARLY_CLEAN" = 1 && rm -rf "$W_TMP_EARLY"
}

winetricks_set_unattended()
{
    # We shouldn't use all these extra variables.  Instead, we should
    # use ${foo:+bar} to jam in commandline options for silent install
    # only if W_OPT_UNATTENDED is nonempty.  See
    # http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_06_02
    # So in attended mode, W_OPT_UNATTENDED should be empty.

    case $1 in
    1)
        W_OPT_UNATTENDED=1
        # Might want to trim our stable of variables here a bit...
        W_UNATTENDED_DASH_Q="-q"
        W_UNATTENDED_SLASH_Q="/q"
        W_UNATTENDED_SLASH_QB="/qb"
        W_UNATTENDED_SLASH_QN="/qn"
        W_UNATTENDED_SLASH_QNT="/qnt"
        W_UNATTENDED_SLASH_QT="/qt"
        W_UNATTENDED_SLASH_QUIET="/quiet"
        W_UNATTENDED_SLASH_S="/S"
        W_UNATTENDED_DASH_SILENT="-silent"
        W_UNATTENDED_SLASH_SILENT="/silent"
        ;;
    *)
        W_OPT_UNATTENDED=""
        W_UNATTENDED_DASH_Q=""
        W_UNATTENDED_SLASH_Q=""
        W_UNATTENDED_SLASH_QB=""
        W_UNATTENDED_SLASH_QN=""
        W_UNATTENDED_SLASH_QNT=""
        W_UNATTENDED_SLASH_QT=""
        W_UNATTENDED_SLASH_QUIET=""
        W_UNATTENDED_SLASH_S=""
        W_UNATTENDED_DASH_SILENT=""
        W_UNATTENDED_SLASH_SILENT=""
        ;;
    esac
}

# Usage: winetricks_set_wineprefix [bottlename]
# Bottlename must not contain spaces, slashes, or other special characters
# If bottlename is omitted, the default bottle (~/.wine) is used.
winetricks_set_wineprefix()
{
    if ! test "$1"
    then
        WINEPREFIX="$WINETRICKS_ORIGINAL_WINEPREFIX"
    else
        WINEPREFIX="$W_PREFIXES_ROOT/$1"
    fi
    export WINEPREFIX
    #echo "WINEPREFIX is now $WINEPREFIX" >&2
    mkdir -p "`dirname "$WINEPREFIX"`"

    # Run wine here to force creation of the wineprefix so it's there when we want to make the cache symlink a bit later.
    # The folder-name is localized!
    W_PROGRAMS_WIN="`w_expand_env ProgramFiles`"
    case "$W_PROGRAMS_WIN" in
    "") w_die "$WINE cmd.exe /c echo '%ProgramFiles%' returned empty string, error message \"`cat $W_TMP_EARLY/early_wine.err.txt`\" ";;
    %*) w_die "$WINE cmd.exe /c echo '%ProgramFiles%' returned unexpanded string '$W_PROGRAMS_WIN' ... this can be caused by a corrupt wineprefix, by an old wine, or by not owning $WINEPREFIX" ;;
    *unknown*) w_die "$WINE cmd.exe /c echo '%ProgramFiles%' returned a string containing the word 'unknown', as if a voice had cried out in terror, and was suddenly silenced." ;;
    esac

    case "$OS" in
    "Windows_NT")
        W_DRIVE_C="/cygdrive/c" ;;
    *)
        W_DRIVE_C="$WINEPREFIX/dosdevices/c:" ;;
    esac

    # Kludge: use Temp instead of temp to avoid \t expansion in w_try
    # but use temp in Unix path because that's what Wine creates, and having both temp and Temp
    # causes confusion (e.g. makes vc2005trial fail)
    if ! test "$1"
    then
        W_TMP="$W_DRIVE_C/windows/temp"
        W_TMP_WIN="C:\\windows\\Temp"
    else
        # Verbs can rely on W_TMP being empty at entry, deleted after return, and a subdir of C:
        W_TMP="$W_DRIVE_C/windows/temp/_$1"
        W_TMP_WIN="C:\\windows\\Temp\\_$1"
    fi

    case "$OS" in
     "Windows_NT")
        W_CACHE_WIN="`w_pathconv -w $W_CACHE`"
        ;;
     *)
        # For case where Z: doesn't exist or / is writable (!),
        # make a drive letter for W_CACHE.  Clean it up on exit.
        test "$WINETRICKS_CACHE_SYMLINK" && rm -f "$WINETRICKS_CACHE_SYMLINK"
        for letter in y x w v u t s r q p o n m
        do
            if ! test -d "$WINEPREFIX"/dosdevices/${letter}:
            then
                mkdir -p "$WINEPREFIX"/dosdevices
                WINETRICKS_CACHE_SYMLINK="$WINEPREFIX"/dosdevices/${letter}:
                ln -sf "$W_CACHE" "$WINETRICKS_CACHE_SYMLINK"
                break
            fi
        done
        W_CACHE_WIN="${letter}:"
        ;;
    esac

    # FIXME: wrong on 64-bit Windows for now
    W_COMMONFILES_X86_WIN="`w_expand_env CommonProgramFiles`"

    W_WINDIR_UNIX="$W_DRIVE_C/windows"

    # FIXME: move that tr into w_pathconv, if it's still needed?
    W_PROGRAMS_UNIX="`w_pathconv -u "$W_PROGRAMS_WIN"`"

    # 64-bit Windows has a second directory for program files
    W_PROGRAMS_X86_WIN="${W_PROGRAMS_WIN} (x86)"
    W_PROGRAMS_X86_UNIX="${W_PROGRAMS_UNIX} (x86)"
    if ! test -d "$W_PROGRAMS_X86_UNIX"
    then
        W_PROGRAMS_X86_WIN="${W_PROGRAMS_WIN}"
        W_PROGRAMS_X86_UNIX="${W_PROGRAMS_UNIX}"
    fi

    W_APPDATA_WIN="`w_expand_env AppData`"
    W_APPDATA_UNIX="`w_pathconv -u "$W_APPDATA_WIN"`"

    # FIXME: get fonts path from SHGetFolderPath
    # See also http://blogs.msdn.com/oldnewthing/archive/2003/11/03/55532.aspx
    W_FONTSDIR_WIN="c:\\windows\\Fonts"

    # FIXME: just convert path from Windows to Unix?
    # Did the user rename Fonts to fonts?
    if test ! -d "$W_WINDIR_UNIX"/Fonts && test -d "$W_WINDIR_UNIX"/fonts
    then
        W_FONTSDIR_UNIX="$W_WINDIR_UNIX"/fonts
    else
        W_FONTSDIR_UNIX="$W_WINDIR_UNIX"/Fonts
    fi
    mkdir -p "${W_FONTSDIR_UNIX}"

    # Win(e) 32/64?
    # Using the variable W_SYSTEM32_DLLS instead of SYSTEM32 because some stuff does go under system32 for both arch's
    # e.g., spool/drivers/color
    if test -d "$W_DRIVE_C/windows/syswow64"
    then
        W_ARCH=win64
        W_SYSTEM32_DLLS="$W_WINDIR_UNIX/syswow64"
        W_SYSTEM32_DLLS_WIN="C:\\windows\\syswow64"
        W_SYSTEM64_DLLS="$W_WINDIR_UNIX/system32"
        W_SYSTEM64_DLLS_WIN32="C:\\windows\\sysnative" # path to access 64-bit dlls from 32-bit apps
        W_SYSTEM64_DLLS_WIN64="C:\\windows\\system32"  # path to access 64-bit dlls from 64-bit apps
        # 64-bit prefixes still have plenty of issues:
        w_warn "You are using a 64-bit WINEPREFIX. If you encounter problems, please retest in a clean 32-bit WINEPREFIX before reporting a bug."
    else
        W_ARCH=win32
        W_SYSTEM32_DLLS="$W_WINDIR_UNIX/system32"
        W_SYSTEM32_DLLS_WIN="C:\\windows\\system32"
    fi
}

winetricks_annihilate_wineprefix()
{
    w_skip_windows "No wineprefix to delete on windows" && return

    case $LANG in
    uk*) w_askpermission "Бажаєте видалити '$WINEPREFIX'?" ;;
    *) w_askpermission "Delete $WINEPREFIX, its apps, icons, and menu items?" ;;
    esac
    rm -rf "$WINEPREFIX"/*
    rm -rf "$WINEPREFIX"

    # Also remove menu items.
    find $XDG_DATA_HOME/applications/wine -type f -name '*.desktop' -exec grep -q -l "$WINEPREFIX" '{}' ';' -exec rm '{}' ';'

    # Also remove desktop items.
    # Desktop might be synonym for home directory, so only go one level
    # deep to avoid extreme slowdown if user has lots of files
    (
    if ! test "$XDG_DESKTOP_DIR" && test -f $XDG_CONFIG_HOME/user-dirs.dirs
    then
        . $XDG_CONFIG_HOME/user-dirs.dirs
    fi
    find "$XDG_DESKTOP_DIR" -maxdepth 1 -type f -name '*.desktop' -exec grep -q -l "$WINEPREFIX" '{}' ';' -exec rm '{}' ';'
    )

    # FIXME: recover more nicely.  At moment, have to restart to avoid trouble.
    exit 0
}

winetricks_init()
{
    #---- Private Variables ----

    if ! test "$USERNAME"
    then
        # Posix only requires LOGNAME to be defined, and sure enough, when
        # logging in via console and startx in Ubuntu 11.04, USERNAME isn't set!
        # And even normal logins in Ubuntu 13.04 doesn't set it.
        # I tried using only LOGNAME in this script, but it's so easy to slip
        # and use USERNAME, so define it here if needed.
        USERNAME="$LOGNAME"
    fi

    # Ephemeral files for this run
    WINETRICKS_WORKDIR="$W_TMP_EARLY/w.$LOGNAME.$$"
    test "$W_OPT_NOCLEAN" = 1 || rm -rf "$WINETRICKS_WORKDIR"

    # Registering a verb creates a file in WINETRICKS_METADATA
    WINETRICKS_METADATA="$WINETRICKS_WORKDIR/metadata"

    # The list of categories is also hardcoded in winetricks_mainmenu() :-(
    WINETRICKS_CATEGORIES="apps benchmarks dlls fonts games settings"
    for _W_cat in $WINETRICKS_CATEGORIES
    do
        mkdir -p "$WINETRICKS_METADATA"/$_W_cat
    done

    # Which subdirectory of WINETRICKS_METADATA is currently active (or main, if none)
    WINETRICKS_CURMENU=prefix

    # Delete work directory after each run, on exit either graceful or abrupt
    trap winetricks_cleanup EXIT HUP INT QUIT ABRT

    # Whether to always cache cached iso's (1) or only use cache if present (0)
    # Can be inherited from environment or set via -k, defaults to off
    WINETRICKS_OPT_KEEPISOS=${WINETRICKS_OPT_KEEPISOS:-0}

    # what program to use to make disc image (dd or ddrescue)
    WINETRICKS_OPT_DD=${WINETRICKS_OPT_DD:-dd}

    # whether to use shared wineprefix (1) or unique wineprefix for each app (0)
    WINETRICKS_OPT_SHAREDPREFIX=${WINETRICKS_OPT_SHAREDPREFIX:-0}

    WINETRICKS_SOURCEFORGE=http://downloads.sourceforge.net

    winetricks_get_sha1sum_prog

    #---- Public Variables ----

    # Where application installers are cached
    # See http://standards.freedesktop.org/basedir-spec/latest/ar01s03.html
    if test -d "$HOME/Library/Caches"
    then
        # OS X
        XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/Library/Caches}"
    else
        XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
    fi
    if test "$WINETRICKS_DIR"
    then
        # For backwards compatibility
        W_CACHE="${W_CACHE:-$WINETRICKS_DIR/cache}"
        WINETRICKS_POST="${WINETRICKS_POST:-$WINETRICKS_DIR/postinstall}"
    else
        W_CACHE="${W_CACHE:-$XDG_CACHE_HOME/winetricks}"
        WINETRICKS_POST="${WINETRICKS_POST:-$XDG_DATA_HOME/winetricks/postinstall}"
    fi
    test -d "$W_CACHE" || mkdir -p "$W_CACHE"
    WINETRICKS_AUTH="${WINETRICKS_AUTH:-$XDG_DATA_HOME/winetricks/auth}"

    # System-specific variables
    case "$OS" in
     "Windows_NT")
        WINE=""
        WINESERVER=""
        W_DRIVE_C="C:/"
        ;;
     *)
        WINE="${WINE:-wine}"
        # Find wineserver.
        # Some distributions (Debian before wine 1.8-2) don't have it on the path.
        for x in \
            "$WINESERVER" \
            "${WINE}server" \
            "`which wineserver 2> /dev/null`" \
            "`dirname $WINE`/server/wineserver" \
            /usr/bin/wineserver-development \
            /usr/lib/wine/wineserver \
            /usr/lib/i386-kfreebsd-gnu/wine/wineserver \
            /usr/lib/i386-linux-gnu/wine/wineserver \
            /usr/lib/powerpc-linux-gnu/wine/wineserver \
            /usr/lib/i386-kfreebsd-gnu/wine/bin/wineserver \
            /usr/lib/i386-linux-gnu/wine/bin/wineserver \
            /usr/lib/powerpc-linux-gnu/wine/bin/wineserver \
            /usr/lib/x86_64-linux-gnu/wine/bin/wineserver \
            /usr/lib/i386-kfreebsd-gnu/wine-development/wineserver \
            /usr/lib/i386-linux-gnu/wine-development/wineserver \
            /usr/lib/powerpc-linux-gnu/wine-development/wineserver \
            /usr/lib/x86_64-linux-gnu/wine-development/wineserver \
            file-not-found
        do
            if test -x "$x"
            then
                case "$x" in
                 /usr/lib/*/wine-development/wineserver|/usr/bin/wineserver-development)
                    if test -x /usr/bin/wine-development
                    then
                        WINE="/usr/bin/wine-development"
                    fi
                    ;;
                esac
                break
            fi
        done
        case "$x" in
        file-not-found)
            w_die "wineserver not found!" ;;
        *)
            WINESERVER="$x" ;;
        esac

        if test "$WINEPREFIX"
        then
            WINETRICKS_ORIGINAL_WINEPREFIX="$WINEPREFIX"
        else
            WINETRICKS_ORIGINAL_WINEPREFIX="$HOME/.wine"
        fi
        _abswine="`which "$WINE" 2>/dev/null`"
        if ! test -x "$_abswine" || ! test -f "$_abswine"
        then
            w_die "WINE is $WINE, which is neither on the path nor an executable file"
        fi
        case "$WINETRICKS_OPT_VERBOSE" in
        1|2) echo -n "Wine is '$WINE'; Wine version is "
             "$WINE" --version || w_die "Can't get Wine version"
             echo "winetricks is $0 ; winetricks version is $WINETRICKS_VERSION"
             ;;
        esac
        unset _abswine
        ;;
    esac
    winetricks_set_wineprefix $1

    # FIXME: don't hardcode
    W_PROGRAMS_DRIVE=c


    # Whether to automate installs (0=no, 1=yes)
    winetricks_set_unattended ${W_OPT_UNATTENDED:-0}

    # Overridden for windows
    W_ISO_MOUNT_ROOT=/mnt/winetricks
    W_ISO_MOUNT_LETTER=i

    WINETRICKS_WINE_VERSION=`winetricks_early_wine --version | sed 's/.*wine/wine/'`
    # A small hack...
    case "$WINETRICKS_WINE_VERSION" in
        wine-1.4-*) WINETRICKS_WINE_VERSION="wine-1.4.40"; export WINETRICKS_WINE_VERSION;;
        wine-1.4) WINETRICKS_WINE_VERSION="wine-1.4.0"; export WINETRICKS_WINE_VERSION;;
        wine-1.6-*) WINETRICKS_WINE_VERSION="wine-1.6.0"; export WINETRICKS_WINE_VERSION;;
        wine-1.6) WINETRICKS_WINE_VERSION="wine-1.6.0"; export WINETRICKS_WINE_VERSION;;
        wine-1.8-*) WINETRICKS_WINE_VERSION="wine-1.8.0"; export WINETRICKS_WINE_VERSION;;
        wine-1.8) WINETRICKS_WINE_VERSION="wine-1.8.0"; export WINETRICKS_WINE_VERSION;;
    esac
    WINETRICKS_WINE_MINOR=`echo $WINETRICKS_WINE_VERSION | sed 's/wine-1\.\([0-9]*\)\..*/\1/'`
    WINETRICKS_WINE_MICRO=`echo $WINETRICKS_WINE_VERSION | sed 's/wine-1.[0-9][0-9]*\.\([0-9]*\).*/\1/'`

    echo "Using winetricks $(winetricks_print_version) with $WINETRICKS_WINE_VERSION"
}

winetricks_usage()
{
    case $LANG in
    da*)
        cat <<_EOF_
Brug: $0 [tilvalg] [verbum|sti-til-verbum] ...
Kører de angivne verber.  Hvert verbum installerer et program eller ændrer en indstilling.
Tilvalg:
-k|--keep_isos: lagr iso'er lokalt (muliggør senere installation uden disk)
-q|--unattended: stil ingen spørgsmål, installér bare automatisk
-r|--ddrescue: brug alternativ disk-tilgangsmetode (hjælper i tilfælde af en ridset disk)
-t|--torify: Run downloads under torify, if available
-v|--verbose: vis alle kommandoer som de bliver udført
-V|--version: vis programversionen og afslut
-h|--help: vis denne besked og afslut
Diverse verber:
list: vis en liste over alle verber
list-cached: vis en liste over verber for allerede-hentede installationsprogrammer
list-download: vis en liste over verber for programmer der kan hentes
list-manual-download: list applications which can be downloaded with some help from the user
list-installed: list already-installed applications
_EOF_
        ;;
    de*)
        cat <<_EOF_
Benutzung: $0 [options] [Kommando|Verb|Pfad-zu-Verb] ...
Angegebene Verben ausführen.
Jedes Verb installiert eine Anwendung oder ändert eine Einstellung.

Optionen:
    --force           Nicht prüfen ob Pakete bereits installiert wurden
    --gui             GUI Diagnosen anzeigen, auch wenn von der Kommandozeile gestartet
    --isolate         Jedes Programm oder Spiel in eigener Bottle (WINEPREFIX) installieren
-k, --keep_isos       ISOs local speichern (erlaubt spätere Installation ohne Disk)
    --no-clean        Temp Verzeichnisse nicht löschen (nützlich beim debuggen)
-q, --unattended      Keine Fragen stellen, alles automatisch installieren
-r, --ddrescue        Alternativer Zugriffsmodus (hilft bei zerkratzten Disks)
    --showbroken      Auch Verben anzeigen die momentan in Wine nicht funktionieren
-t  --torify          Run downloads under torify, if available
    --verify          Wenn Möglisch automatische GUI Tests für Verben starten
-v, --verbose         Alle ausgeführten Kommandos anzeigen
-h, --help            Diese Hilfemeldung anzeigen
-V, --version         Programmversion anzeigen und Beenden

Kommandos:
list                  Kategorien auflisten
list-all              Alle Kategorien und deren Verben auflisten
apps list             Verben der Kategorie 'Anwendungen' auflisten
benchmarks list       Verben der Kategorie 'Benchmarks' auflisten
dlls list             Verben der Kategorie 'DLLs' auflisten
games list            Verben der Kategorie 'Spiele' auflisten
settings list         Verben der Kategorie 'Einstellungen' auflisten
list-cached           Verben für bereits gecachte Installers auflisten
list-download         Verben für automatisch herunterladbare Anwendungen auflisten
list-manual-download  Verben für vom Benutzer herunterladbare Anwendungen auflisten
list-installed        Bereits installierte Verben auflisten
prefix=foobar         WINEPREFIX=$W_PREFIXES_ROOT/foobar auswählen
_EOF_
        ;;
    *)
        cat <<_EOF_
Usage: $0 [options] [command|verb|path-to-verb] ...
Executes given verbs.  Each verb installs an application or changes a setting.

Options:
    --force           Don't check whether packages were already installed
    --gui             Show gui diagnostics even when driven by commandline
    --isolate         Install each app or game in its own bottle (WINEPREFIX)
    --self-update     Update this application to the last version
    --update-rollback Rollback the last self update
-k, --keep_isos       Cache isos (allows later installation without disc)
    --no-clean        Don't delete temp directories (useful during debugging)
-q, --unattended      Don't ask any questions, just install automatically
-r, --ddrescue        Retry hard when caching scratched discs
    --showbroken      Even show verbs that are currently broken in wine
-t  --torify          Run downloads under torify, if available
    --verify          Run (automated) GUI tests for verbs, if available
-v, --verbose         Echo all commands as they are executed
-h, --help            Display this message and exit
-V, --version         Display version and exit

Commands:
list                  list categories
list-all              list all categories and their verbs
apps list             list verbs in category 'applications'
benchmarks list       list verbs in category 'benchmarks'
dlls list             list verbs in category 'dlls'
games list            list verbs in category 'games'
settings list         list verbs in category 'settings'
list-cached           list cached-and-ready-to-install verbs
list-download         list verbs which download automatically
list-manual-download  list verbs which download with some help from the user
list-installed        list already-installed verbs
prefix=foobar         select WINEPREFIX=$W_PREFIXES_ROOT/foobar
_EOF_
        ;;
    esac
}

winetricks_handle_option()
{
    case "$1" in
    -r|--ddrescue) WINETRICKS_OPT_DD=ddrescue ;;
    -k|--keep_isos) WINETRICKS_OPT_KEEPISOS=1 ;;
    -q|--unattended) winetricks_set_unattended 1 ;;
    -t|--torify)  WINETRICKS_OPT_TORIFY=1 ;;
    -v|--verbose) WINETRICKS_OPT_VERBOSE=1 ; set -x;;
    -vv|--really-verbose) WINETRICKS_OPT_VERBOSE=2 ; set -x ;;
    -V|--version) winetricks_print_version ; exit 0;;
    --verify) WINETRICKS_VERIFY=1 ;;
    -h|--help) winetricks_usage ; exit 0 ;;
    --self-update) winetricks_selfupdate;;
    --update-rollback) winetricks_selfupdate_rollback;;
    --isolate) WINETRICKS_OPT_SHAREDPREFIX=0 ;;
    --no-isolate) WINETRICKS_OPT_SHAREDPREFIX=1 ;;
    --no-clean) W_OPT_NOCLEAN=1 ;;
    --force) WINETRICKS_FORCE=1;;
    --gui) winetricks_detect_gui;;
    --showbroken) W_OPT_SHOWBROKEN=1 ;;
    --optin) WINETRICKS_STATS_REPORT=1;;
    --optout) WINETRICKS_STATS_REPORT=0;;
    -*) w_die "unknown option $1" ;;
    *) return 1 ;;
    esac
    return 0
}

# Must initialize variables before calling w_metadata
if ! test "$WINETRICKS_LIB"
then
    WINETRICKS_SRCDIR=`dirname "$0"`
    WINETRICKS_SRCDIR=`cd "$WINETRICKS_SRCDIR"; pwd`

    # Which GUI helper to use (none/zenity/kdialog).  See winetricks_detect_gui.
    WINETRICKS_GUI=none
    # Default to a shared prefix:
    WINETRICKS_OPT_SHAREDPREFIX=${WINETRICKS_OPT_SHAREDPREFIX:-1}

    # Handle options before init, to avoid starting wine for --help or --version
    while winetricks_handle_option $1
    do
        shift
    done

    # Workaround for https://github.com/Winetricks/winetricks/issues/599
    # If --isolate is used, pass verb to winetricks_init, so it can set the wineprefix using winetricks_set_wineprefix()
    # Otherwise, an arch mismatch between ${WINEPREFIX:-$HOME/.wine} and the prefix to be made for the isolated app would cause it to fail
    case $WINETRICKS_OPT_SHAREDPREFIX in
        0) winetricks_init $1 ;;
        *) winetricks_init ;;
    esac
fi

winetricks_install_app()
{
    case $LANG in
    da*) fail_msg="Installationen af pakken $1 fejlede" ;;
    de*) fail_msg="Installieren von Paket $1 gescheitert" ;;
    pl*) fail_msg="Niepowodzenie przy instalacji paczki $1" ;;
    ru*) fail_msg="Ошибка установки пакета $1" ;;
    uk*) fail_msg="Помилка встановлення пакунка $1" ;;
    zh_CN*)   fail_msg="$1 安装失败" ;;
    zh_TW*|zh_HK*)   fail_msg="$1 安裝失敗" ;;
    *)   fail_msg="Failed to install package $1" ;;
    esac

    # FIXME: initialize a new wineprefix for this app, set lots of global variables
    if ! w_do_call $1 $2
    then
        w_die "$fail_msg"
    fi
}

#---- Builtin Verbs ----

#----------------------------------------------------------------
# Runtimes
#----------------------------------------------------------------

#----- common download for several verbs

helper_directx_dl()
{
    # February 2010 DirectX 9c User Redistributable
    # http://www.microsoft.com/downloads/details.aspx?displaylang=en&FamilyID=0cef8180-e94a-4f56-b157-5ab8109cb4f5
    # FIXME: none of the verbs that use this will show download status right
    # until file1 metadata is extended to handle common cache dir
    w_download_to directx9 http://download.microsoft.com/download/E/E/1/EE17FF74-6C45-4575-9CF4-7FC2597ACD18/directx_feb2010_redist.exe a97c820915dc20929e84b49646ec275760012a42

    DIRECTX_NAME=directx_feb2010_redist.exe
}

helper_directx_Jun2010()
{
    # June 2010 DirectX 9c User Redistributable
    # http://www.microsoft.com/downloads/en/details.aspx?FamilyID=3b170b25-abab-4bc3-ae91-50ceb6d8fa8d
    w_download_to directx9 http://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe

    DIRECTX_NAME=directx_Jun2010_redist.exe
}

helper_d3dx9_xx()
{
    dllname=d3dx9_$1

    helper_directx_dl

    # Even kinder, less invasive directx - only extract and override d3dx9_xx.dll
    w_try_cabextract -d "$W_TMP" -L -F "*$dllname*x86*" "$W_CACHE"/directx9/$DIRECTX_NAME
    for x in "$W_TMP"/*.cab
    do
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F "$dllname.dll" "$x"
    done
    if test "$W_ARCH" = "win64"
    then
        w_try_cabextract -d "$W_TMP" -L -F "*$dllname*x64*" "$W_CACHE"/directx9/$DIRECTX_NAME
        for x in "$W_TMP"/*x64.cab
        do
            w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F "$dllname.dll" "$x"
        done
    fi

    w_override_dlls native $dllname
}

helper_win2ksp4()
{
    filename=$1

    # http://www.microsoft.com/downloads/details.aspx?FamilyID=1001AAF1-749F-49F4-8010-297BD6CA33A0&displaylang=en
    w_download_to win2ksp4 http://download.microsoft.com/download/E/6/A/E6A04295-D2A8-40D0-A0C5-241BFECD095E/W2KSP4_EN.EXE fadea6d94a014b039839fecc6e6a11c20afa4fa8
    w_try_cabextract -d "$W_TMP" -L -F $filename "$W_CACHE"/win2ksp4/W2KSP4_EN.EXE
}

helper_xpsp3()
{
    filename=$1

    # http://www.microsoft.com/en-us/download/details.aspx?id=24
    w_download_to xpsp3 http://download.microsoft.com/download/d/3/0/d30e32d8-418a-469d-b600-f32ce3edf42d/WindowsXP-KB936929-SP3-x86-ENU.exe c81472f7eeea2eca421e116cd4c03e2300ebfde4

    w_try_cabextract -d "$W_TMP" -L -F $filename "$W_CACHE"/xpsp3/WindowsXP-KB936929-SP3-x86-ENU.exe
}

helper_win7sp1()
{
    filename=$1

    # https://www.microsoft.com/en-us/download/details.aspx?id=5842
    w_download_to win7sp1 http://download.microsoft.com/download/0/A/F/0AFB5316-3062-494A-AB78-7FB0D4461357/windows6.1-KB976932-X86.exe c3516bc5c9e69fee6d9ac4f981f5b95977a8a2fa

    w_try_cabextract -d "$W_TMP" -L -F $filename "$W_CACHE"/win7sp1/windows6.1-KB976932-X86.exe
}

#---------------------------------------------------------

w_metadata adobeair dlls \
    title="Adobe AIR 20.x" \
    publisher="Adobe" \
    year="2015" \
    media="download" \
    file1="AdobeAIRInstaller.exe" \
    installed_file1="$W_COMMONFILES_X86_WIN/Adobe AIR/Versions/1.0/Adobe AIR.dll" \
    homepage="http://www.adobe.com/products/air/"

load_adobeair()
{
    # 2010-02-02: sha1sum 5c95f51a680f8c175a92755238127be4ad22c53b
    # 2010-02-20: sha1sum 6f03e723bd855abbe00eb8fdf22da54fb49c62db
    # 2010-07-29: 2.0.2 sha1sum 7b93aedaf48ad7854940e7a4e7d9394a255e888b
    # 2010-12-08: 2.5.1 sha1sum 2664207ca8e836f5070ee356064829a39785a92e
    # 2011-04-13: 2.6   sha1sum 3d9c2f9d8f3533424cfea84d61fcb9464278d9fc
    # 2011-10-26: 2.7   sha1sum dfa337d4b53e9d924356febc116450190fa183dd
    # 2014-03-01: 4.0   sha1sum 0034bdd4e0b2ce0fa6198b0b715fba85754d9a57
    # http://helpx.adobe.com/en/flash-player/release-note/fp_12_air_4_release_notes.html
    # 2014-09-30: 15.0  sha1sum 46341f1358bc6e0b9ddeae3591662a2ac68dc360
    # 2014-11-24: 15.0.0.356 sha1sum c0e6b8b1ed5ffa282945d21b21f8a5e03febc904
    # 2015-11-06: 19.x sha1sum 3bc2a568204a3a9b59ca347ab49585f0c5fab279
    # 2015-12-27: 20.0 sha1sum 9c10b7be43771869c381c73197c9a0fcd1b727cf
    # 2015-12-29: 20.0.0.233 (had to check with strings on Adobe AIR.dll) sha1sum 7161fb8b47721485882f52720f8b41dbfe3b69d0
    # 2016-02-17: 20.0.0.260 (strings 'Adobe AIR.dll' | grep 20\\. ) sha1sum 2fdd561556fe881c4e5538d4ee37f523871befd3

    w_download http://airdownload.adobe.com/air/win/download/20.0/AdobeAIRInstaller.exe 2fdd561556fe881c4e5538d4ee37f523871befd3
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" AdobeAIRInstaller.exe $W_UNATTENDED_DASH_SILENT
}

#----------------------------------------------------------------

w_metadata amstream dlls \
    title="MS amstream.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/amstream.dll"

load_amstream()
{
    helper_directx_dl
    mkdir "$W_CACHE"/amstream   # kludge so test -f $file1 works

    w_try_cabextract -d "$W_TMP" -L -F dxnt.cab "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'amstream.dll' "$W_TMP/dxnt.cab"
    w_try_regsvr amstream.dll

    w_override_dlls native amstream
}

#----------------------------------------------------------------

w_metadata art2kmin dlls \
    title="MS Access 2007 runtime" \
    publisher="Microsoft" \
    year="2007" \
    media="download" \
    file1="AccessRuntime.exe" \
    installed_file1="$W_COMMONFILES_X86_WIN/Microsoft Shared/OFFICE12/ACEES.DLL"

load_art2kmin()
{
    # See http://www.microsoft.com/downloads/details.aspx?familyid=d9ae78d9-9dc6-4b38-9fa6-2c745a175aed&displaylang=en
    w_download http://download.microsoft.com/download/D/2/A/D2A2FC8B-0447-491C-A5EF-E8AA3A74FB98/AccessRuntime.exe 571811b7536e97cf4e4e53bbf8260cddd69f9b2d
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" AccessRuntime.exe $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata atmlib dlls \
    title="Adobe Type Manager" \
    publisher="Adobe" \
    year="2009" \
    media="download" \
    file1="../win2ksp4/W2KSP4_EN.EXE" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/atmlib.dll"

load_atmlib()
{
    helper_win2ksp4 i386/atmlib.dl_
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_TMP"/i386/atmlib.dl_
}

#----------------------------------------------------------------

w_metadata avifil32 dlls \
    title="MS avifil32" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="../xpsp3/WindowsXP-KB936929-SP3-x86-ENU.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/avifil32.dll"

load_avifil32()
{
    helper_xpsp3 i386/avifil32.dl_
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_TMP"/i386/avifil32.dl_

    w_override_dlls native avifil32
}

#----------------------------------------------------------------

w_metadata cabinet dlls \
    title="Microsoft cabinet.dll" \
    publisher="Microsoft" \
    year="2002" \
    media="download" \
    file1="mdac_typ.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/cabinet.dll"

load_cabinet()
{
    # http://www.microsoft.com/downloads/en/details.aspx?FamilyId=9AD000F2-CAE7-493D-B0F3-AE36C570ADE8&displaylang=en
    w_download http://download.microsoft.com/download/3/b/f/3bf74b01-16ba-472d-9a8c-42b2b4fa0d76/mdac_typ.exe f68594d1f578c3b47bf0639c46c11c5da161feee
    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/cabinet/$file1
    w_try cp "$W_TMP"/cabinet.dll "$W_SYSTEM32_DLLS"/cabinet.dll

    w_override_dlls native,builtin cabinet
}

#----------------------------------------------------------------

w_metadata cmd dlls \
    title="MS cmd.exe" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="Q811493_W2K_SP4_X86_EN.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/cmd.exe"

load_cmd()
{
    w_download http://download.microsoft.com/download/8/d/c/8dc79965-dfbc-4b25-9546-e23bc4b791c6/Q811493_W2K_SP4_X86_EN.exe ac6e28cfd12942e74aa08bddf7715705edb85b6b
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_CACHE/$W_PACKAGE/$file1" -F cmd.exe

    w_override_dlls native,builtin cmd.exe
}

#----------------------------------------------------------------

w_metadata comctl32 dlls \
    title="MS common controls 5.80" \
    publisher="Microsoft" \
    year="2001" \
    media="download" \
    file1="cc32inst.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/comctl32.dll"

load_comctl32()
{
    # 2011-01-17: http://www.microsoft.com/downloads/details.aspx?familyid=6f94d31a-d1e0-4658-a566-93af0d8d4a1e
    # 2012-08-11: w_download http://download.microsoft.com/download/platformsdk/redist/5.80.2614.3600/w9xnt4/en-us/cc32inst.exe 94c3c494258cc54bd65d2f0153815737644bffde
    # 2016/01/07: w_download ftp://ftp.ie.debian.org/disk1/download.sourceforge.net/pub/sourceforge/p/po/pocmin/Win%2095_98%20Controls/Win%2095_98%20Controls/CC32inst.exe

    w_download ftp://ftp.ie.debian.org/disk1/download.sourceforge.net/pub/sourceforge/p/po/pocmin/Win%2095_98%20Controls/Win%2095_98%20Controls/CC32inst.exe 94c3c494258cc54bd65d2f0153815737644bffde cc32inst.exe

    w_try "$WINE" "$W_CACHE"/comctl32/cc32inst.exe "/T:$W_TMP_WIN" /c $W_UNATTENDED_SLASH_Q
    w_try_unzip "$W_TMP" "$W_TMP"/comctl32.exe
    w_try "$WINE" "$W_TMP"/x86/50ComUpd.Exe "/T:$W_TMP_WIN" /c $W_UNATTENDED_SLASH_Q
    w_try cp "$W_TMP"/comcnt.dll "$W_SYSTEM32_DLLS"/comctl32.dll

    w_override_dlls native,builtin comctl32

    # some builtin apps don't like native comctl32
    w_override_app_dlls winecfg.exe builtin comctl32
    w_override_app_dlls explorer.exe builtin comctl32
    w_override_app_dlls iexplore.exe builtin comctl32
}

#----------------------------------------------------------------

w_metadata comctl32ocx dlls \
    title="MS comctl32.ocx and mscomctl.ocx, comctl32 wrappers for VB6" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="VisualBasic6-KB896559-v1-ENU.exe" \
    file2="mscomct2.cab" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/mscomctl.ocx"

load_comctl32ocx()
{
    # http://www.microsoft.com/downloads/details.aspx?FamilyID=25437D98-51D0-41C1-BB14-64662F5F62FE
    w_download http://download.microsoft.com/download/3/a/5/3a5925ac-e779-4b1c-bb01-af67dc2f96fc/VisualBasic6-KB896559-v1-ENU.exe f52cf2034488235b37a1da837d1c40eb2a1bad84
    # More ActiveX controls. See https://support.microsoft.com/kb/297381
    w_download http://activex.microsoft.com/controls/vb6/mscomct2.cab 766f9ccf8849a04d757faee379da54d635c8ac71

    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/comctl32ocx/VisualBasic6-KB896559-v1-ENU.exe
    w_try cp "$W_TMP"/mscomctl.ocx "$W_SYSTEM32_DLLS"/mscomctl.ocx
    w_try cp "$W_TMP"/comctl32.ocx "$W_SYSTEM32_DLLS"/comctl32.ocx
    w_try_regsvr comctl32.ocx
    w_try_regsvr mscomctl.ocx

    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/comctl32ocx/mscomct2.cab
    w_try cp "$W_TMP"/mscomct2.ocx "$W_SYSTEM32_DLLS"/mscomct2.ocx
    w_try_regsvr mscomct2.ocx
}

#----------------------------------------------------------------

w_metadata comdlg32ocx dlls \
    title="Common Dialog ActiveX Control for VB6" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="ComDlg32.cab" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/comdlg32.ocx"

load_comdlg32ocx()
{
    # By analogy with vb5 version in http://support.microsoft.com/kb/168917
    w_download http://activex.microsoft.com/controls/vb6/ComDlg32.cab d4f3e193c6180eccd73bad53a8500beb5b279cbf
    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/comdlg32ocx/${file1}
    w_try cp "$W_TMP"/comdlg32.ocx "$W_SYSTEM32_DLLS"/comdlg32.ocx
    w_try_regsvr comdlg32.ocx
}

#----------------------------------------------------------------

w_metadata crypt32 dlls \
    title="MS crypt32" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="../xpsp3/WindowsXP-KB936929-SP3-x86-ENU.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/crypt32.dll"

load_crypt32()
{
    w_call msasn1

    helper_xpsp3 i386/crypt32.dl_
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_TMP"/i386/crypt32.dl_

    w_override_dlls native crypt32
}

#----------------------------------------------------------------

w_metadata binkw32 dlls \
    title="RAD Game Tools binkw32.dll" \
    publisher="RAD Game Tools, Inc." \
    year="2000" \
    media="download" \
    file1="__32-binkw32.dll3.0.0.0.zip" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/binkw32.dll"

load_binkw32()
{
    # Mirror: http://www.dlldump.com/download-dll-files_new.php/dllfiles/B/binkw32.dll/1.0q/download.html
    # Sha1sum of the decompressed file: 613f81f82e12131e86ae60dd318941f40db2200f
    #
    # Zip sha1sum:
    # 2015-03-28: 991f77e8df513ccb8663dc4a2753fbf90338ef5c
    # 2015-12-27: 6a30900885390ef361dbb67444a7944143db36bf
    w_download http://www.down-dll.com/dll/b/__32-binkw32.dll3.0.0.0.zip 6a30900885390ef361dbb67444a7944143db36bf

    w_try_unzip "$W_TMP" "$W_CACHE"/binkw32/__32-binkw32.dll3.0.0.0.zip
    w_try cp "$W_TMP"/binkw32.dll "$W_SYSTEM32_DLLS"/binkw32.dll

    w_override_dlls native binkw32
}

#----------------------------------------------------------------

w_metadata d3dcompiler_43 dlls \
    title="MS d3dcompiler_43.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_Jun2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dcompiler_43.dll" \
    wine_showstoppers="24013"   # list a showstopper to hide this from average users for now

load_d3dcompiler_43()
{
    dllname=d3dcompiler_43

    helper_directx_Jun2010

    w_try_cabextract -d "$W_TMP" -L -F "*$dllname*x86*" "$W_CACHE"/directx9/$DIRECTX_NAME
    for x in "$W_TMP"/*.cab
    do
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F "$dllname.dll" "$x"
    done
    if test "$W_ARCH" = "win64"
    then
        w_try_cabextract -d "$W_TMP" -L -F "*$dllname*x64*" "$W_CACHE"/directx9/$DIRECTX_NAME
        for x in "$W_TMP"/*x64.cab
        do
            w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F "$dllname.dll" "$x"
        done
    fi

    w_override_dlls native $dllname
}

#----------------------------------------------------------------

w_metadata d3drm dlls \
    title="MS d3drm.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3drm.dll"

load_d3drm()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F "dxnt.cab" "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F "d3drm.dll" "$W_TMP/dxnt.cab"

    w_override_dlls native d3drm
}

#----------------------------------------------------------------

w_metadata d3dx9 dlls \
    title="MS d3dx9_??.dll from DirectX 9 redistributable" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_Jun2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx9_43.dll"

load_d3dx9()
{
    helper_directx_Jun2010

    # Kinder, less invasive directx - only extract and override d3dx9_??.dll
    w_try_cabextract -d "$W_TMP" -L -F '*d3dx9*x86*' "$W_CACHE"/directx9/$DIRECTX_NAME
    for x in "$W_TMP"/*.cab
    do
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'd3dx9*.dll' "$x"
    done
    if test "$W_ARCH" = "win64"
    then
        w_try_cabextract -d "$W_TMP" -L -F '*d3dx9*x64*' "$W_CACHE"/directx9/$DIRECTX_NAME
        for x in "$W_TMP"/*x64.cab
        do
            w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F 'd3dx9*.dll' "$x"
        done
    fi

    # For now, not needed, but when Wine starts preferring our builtin dll over native it will be.
    w_override_dlls native d3dx9_24 d3dx9_25 d3dx9_26 d3dx9_27 d3dx9_28 d3dx9_29 d3dx9_30
    w_override_dlls native d3dx9_31 d3dx9_32 d3dx9_33 d3dx9_34 d3dx9_35 d3dx9_36 d3dx9_37
    w_override_dlls native d3dx9_38 d3dx9_39 d3dx9_40 d3dx9_41 d3dx9_42 d3dx9_43
}

#----------------------------------------------------------------

w_metadata d3dx9_26 dlls \
    title="MS d3dx9_26.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx9_26.dll"

load_d3dx9_26()
{
    helper_d3dx9_xx 26
}

#----------------------------------------------------------------

w_metadata d3dx9_28 dlls \
    title="MS d3dx9_28.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx9_28.dll"

load_d3dx9_28()
{
    helper_d3dx9_xx 28
}

#----------------------------------------------------------------

w_metadata d3dx9_31 dlls \
    title="MS d3dx9_31.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx9_31.dll"

load_d3dx9_31()
{
    helper_d3dx9_xx 31
}

#----------------------------------------------------------------

w_metadata d3dx9_35 dlls \
    title="MS d3dx9_35.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx9_35.dll"

load_d3dx9_35()
{
    helper_d3dx9_xx 35
}

#----------------------------------------------------------------

w_metadata d3dx9_36 dlls \
    title="MS d3dx9_36.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx9_36.dll"

load_d3dx9_36()
{
    helper_d3dx9_xx 36
}

#----------------------------------------------------------------

w_metadata d3dx9_39 dlls \
    title="MS d3dx9_39.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx9_39.dll"

load_d3dx9_39()
{
    helper_d3dx9_xx 39
}

#----------------------------------------------------------------

w_metadata d3dx9_42 dlls \
    title="MS d3dx9_42.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx9_42.dll"

load_d3dx9_42()
{
    helper_d3dx9_xx 42
}

#----------------------------------------------------------------

w_metadata d3dx9_43 dlls \
    title="MS d3dx9_43.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_Jun2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx9_43.dll"

load_d3dx9_43()
{
    dllname=d3dx9_43

    helper_directx_Jun2010

    w_try_cabextract -d "$W_TMP" -L -F "*$dllname*x86*" "$W_CACHE"/directx9/$DIRECTX_NAME
    for x in "$W_TMP"/*.cab
    do
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F "$dllname.dll" "$x"
    done
    if test "$W_ARCH" = "win64"
    then
        w_try_cabextract -d "$W_TMP" -L -F "*$dllname*x64*" "$W_CACHE"/directx9/$DIRECTX_NAME
        for x in "$W_TMP"/*x64.cab
        do
            w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F "$dllname.dll" "$x"
        done
    fi

    w_override_dlls native $dllname
}

#----------------------------------------------------------------

w_metadata d3dx11_42 dlls \
    title="MS d3dx11_42.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_Jun2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx11_42.dll"

load_d3dx11_42()
{
    dllname=d3dx11_42

    helper_directx_Jun2010

    w_try_cabextract -d "$W_TMP" -L -F "*$dllname*x86*" "$W_CACHE"/directx9/$DIRECTX_NAME
    for x in "$W_TMP"/*.cab
    do
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F "$dllname.dll" "$x"
    done
    if test "$W_ARCH" = "win64"
    then
        w_try_cabextract -d "$W_TMP" -L -F "*$dllname*x64*" "$W_CACHE"/directx9/$DIRECTX_NAME
        for x in "$W_TMP"/*x64.cab
        do
            w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F "$dllname.dll" "$x"
        done
    fi

    w_override_dlls native $dllname
}

#----------------------------------------------------------------

w_metadata d3dx11_43 dlls \
    title="MS d3dx11_43.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_Jun2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx11_43.dll"

load_d3dx11_43()
{
    dllname=d3dx11_43

    helper_directx_Jun2010

    w_try_cabextract -d "$W_TMP" -L -F "*$dllname*x86*" "$W_CACHE"/directx9/$DIRECTX_NAME
    for x in "$W_TMP"/*.cab
    do
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F "$dllname.dll" "$x"
    done
    if test "$W_ARCH" = "win64"
    then
        w_try_cabextract -d "$W_TMP" -L -F "*$dllname*x64*" "$W_CACHE"/directx9/$DIRECTX_NAME
        for x in "$W_TMP"/*x64.cab
        do
            w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F "$dllname.dll" "$x"
        done
    fi

    w_override_dlls native $dllname
}

#----------------------------------------------------------------

w_metadata d3dx10 dlls \
    title="MS d3dx10_??.dll from DirectX user redistributable" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_Jun2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx10_33.dll"

load_d3dx10()
{
    helper_directx_Jun2010

    # Kinder, less invasive directx10 - only extract and override d3dx10_??.dll
    w_try_cabextract -d "$W_TMP" -L -F '*d3dx10*x86*' "$W_CACHE"/directx9/$DIRECTX_NAME
    for x in "$W_TMP"/*.cab
    do
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'd3dx10*.dll' "$x"
    done
    if test "$W_ARCH" = "win64"
    then
        w_try_cabextract -d "$W_TMP" -L -F '*d3dx10*x64*' "$W_CACHE"/directx9/$DIRECTX_NAME
        for x in "$W_TMP"/*x64.cab
        do
            w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F 'd3dx10*.dll' "$x"
        done
    fi

    # For now, not needed, but when Wine starts preferring our built-in DLL over native it will be.
    w_override_dlls native d3dx10_33 d3dx10_34 d3dx10_35 d3dx10_36 d3dx10_37
    w_override_dlls native d3dx10_38 d3dx10_39 d3dx10_40 d3dx10_41 d3dx10_42 d3dx10_43
}

#----------------------------------------------------------------

w_metadata d3dx10_43 dlls \
    title="MS d3dx10_43.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_Jun2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx10_43.dll"

load_d3dx10_43()
{
    dllname=d3dx10_43

    helper_directx_Jun2010

    w_try_cabextract -d "$W_TMP" -L -F "*$dllname*x86*" "$W_CACHE"/directx9/$DIRECTX_NAME
    for x in "$W_TMP"/*.cab
    do
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F "$dllname.dll" "$x"
    done
    if test "$W_ARCH" = "win64"
    then
        w_try_cabextract -d "$W_TMP" -L -F "*$dllname*x64*" "$W_CACHE"/directx9/$DIRECTX_NAME
        for x in "$W_TMP"/*x64.cab
        do
            w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F "$dllname.dll" "$x"
        done
    fi

    w_override_dlls native $dllname
}

#----------------------------------------------------------------

w_metadata d3dxof dlls \
    title="MS d3dxof.dll from DirectX user redistributable" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dxof.dll"

load_d3dxof()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F 'dxnt.cab' "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'd3dxof.dll' "$W_TMP/dxnt.cab"

    w_override_dlls native d3dxof
}

#----------------------------------------------------------------

w_metadata dbghelp dlls \
    title="MS dbghelp" \
    publisher="Microsoft" \
    year="2008" \
    media="download" \
    file1="../xpsp3/WindowsXP-KB936929-SP3-x86-ENU.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/dbghelp.dll"

load_dbghelp()
{
    helper_xpsp3 i386/dbghelp.dll

    w_try cp -f "$W_TMP"/i386/dbghelp.dll "$W_SYSTEM32_DLLS"

    w_override_dlls native dbghelp
}

#----------------------------------------------------------------

w_metadata devenum dlls \
    title="MS devenum.dll from DirectX user redistributable" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/devenum.dll"

load_devenum()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F 'dxnt.cab' "$W_CACHE/directx9/$DIRECTX_NAME"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'devenum.dll' "$W_TMP/dxnt.cab"
    w_try_regsvr devenum.dll
    w_override_dlls native devenum
}

#----------------------------------------------------------------

w_metadata dinput dlls \
    title="MS dinput.dll; breaks mouse, use only on Rayman 2 etc." \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/dinput.dll"

load_dinput()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F 'dxnt.cab' "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dinput.dll' "$W_TMP/dxnt.cab"
    w_try_regsvr dinput
    w_override_dlls native dinput
}

#----------------------------------------------------------------

w_metadata dinput8 dlls \
    title="MS DirectInput 8 from DirectX user redistributable" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/dinput8.dll"

load_dinput8()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F 'dxnt.cab' "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dinput8.dll' "$W_TMP/dxnt.cab"
    w_try_regsvr dinput8
    w_override_dlls native dinput8
}

#----------------------------------------------------------------

w_metadata directmusic dlls \
    title="MS DirectMusic from DirectX user redistributable" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/dmusic.dll"

load_directmusic()
{
# Untested. Based off http://bugs.winehq.org/show_bug.cgi?id=4805 and http://bugs.winehq.org/show_bug.cgi?id=24911

    w_call dsound

    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F dxnt.cab "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'devenum.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dmband.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dmcompos.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dmime.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dmloader.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dmscript.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dmstyle.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dmsynth.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dmusic.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dmusic32.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dswave.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'streamci.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'quartz.dll' "$W_TMP/dxnt.cab"

    w_try_regsvr devenum.dll
    w_try_regsvr dmband.dll
    w_try_regsvr dmcompos.dll
    w_try_regsvr dmime.dll
    w_try_regsvr dmloader.dll
    w_try_regsvr dmscript.dll
    w_try_regsvr dmstyle.dll
    w_try_regsvr dmsynth.dll
    w_try_regsvr dmusic.dll
    w_try_regsvr dswave.dll
    w_try_regsvr quartz.dll

    w_override_dlls native devenum dmband dmcompos dmime dmloader dmscript dmstyle dmsynth dmusic dmusic32 dswave streamci quartz
}

#----------------------------------------------------------------

w_metadata directplay dlls \
    title="MS DirectPlay from DirectX user redistributable" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/dplayx.dll"

load_directplay()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F dxnt.cab "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dplaysvr.exe' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dplayx.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dpnet.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dpnhpast.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dpnsvr.exe' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dpwsockx.dll' "$W_TMP/dxnt.cab"

    w_override_dlls native dplayx dpnet dpnhpast dpnsvr.exe dpwsockx

    w_try_regsvr dplayx.dll
    w_try_regsvr dpnet.dll
    w_try_regsvr dpnhpast.dll
}

#----------------------------------------------------------------

w_metadata directx9 dlls \
    title="MS DirectX 9 (Usually overkill.  Try d3dx9_36 first)" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/d3dx10_33.dll"

load_directx9()
{
    helper_directx_dl

    w_warn "You probably shouldn't be using this.  d3dx9 or, better, d3dx9_36 usually suffice."

    # Stefan suggested that, when installing, one should override as follows:
    # 1) use built-in wintrust (we don't run native properly somehow?)
    # 2) disable mscoree (else if it's present some module misbehaves?)
    # 3) override native any DirectX DLL whose Wine version doesn't register itself well yet
    # For #3, I have no idea which DLLs don't register themselves well yet,
    # so I'm just listing a few of the basic ones.  Let's whittle that
    # list down as soon as we can.

    # Setting Windows version to win2k apparently crashes the installer on OS X.
    # See http://code.google.com/p/winezeug/issues/detail?id=71
    w_set_winver winxp

    cd "$W_CACHE/$W_PACKAGE"
    WINEDLLOVERRIDES="wintrust=b,mscoree=,ddraw,d3d8,d3d9,dsound,dinput=n" \
        w_try "$WINE" $DIRECTX_NAME /t:"$W_TMP_WIN" $W_UNATTENDED_SLASH_Q

    # How many of these do we really need?
    # We should probably remove most of these...?
    w_override_dlls native d3dim d3drm d3dx8 d3dx9_24 d3dx9_25 d3dx9_26 d3dx9_27 d3dx9_28 d3dx9_29
    w_override_dlls native d3dx9_30 d3dx9_31 d3dx9_32 d3dx9_33 d3dx9_34 d3dx9_35 d3dx9_36 d3dx9_37
    w_override_dlls native d3dx9_38 d3dx9_39 d3dx9_40 d3dx9_41 d3dx9_42 d3dx9_43 d3dxof
    w_override_dlls native dciman32 ddrawex devenum dmband dmcompos dmime dmloader dmscript dmstyle
    w_override_dlls native dmsynth dmusic dmusic32 dnsapi dplay dplayx dpnaddr dpnet dpnhpast dpnlobby
    w_override_dlls native dswave dxdiagn msdmo qcap quartz streamci
    w_override_dlls native dxdiag.exe
    w_override_dlls builtin d3d8 d3d9 dinput dinput8 dsound

    w_try "$WINE" "$W_TMP_WIN"\\DXSETUP.exe $W_UNATTENDED_SLASH_SILENT
}

#----------------------------------------------------------------

w_metadata dpvoice dlls \
    title="Microsoft dpvoice dpvvox dpvacm Audio dlls" \
    publisher="Microsoft" \
    year="2002" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/dpvoice.dll" \
    installed_file2="$W_SYSTEM32_DLLS_WIN/dpvvox.dll" \
    installed_file2="$W_SYSTEM32_DLLS_WIN/dpvacm.dll"

load_dpvoice()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F 'dxnt.cab' "$W_CACHE"/directx9/$DIRECTX_NAME
    for x in "$W_TMP"/*.cab
    do
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dpvoice.dll' "$x"
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dpvvox.dll' "$x"
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dpvacm.dll' "$x"
    done
    w_try_regsvr dpvoice.dll
    w_try_regsvr dpvvox.dll
    w_try_regsvr dpvacm.dll
    w_override_dlls native dpvoice
    w_override_dlls native dpvvox
    w_override_dlls native dpvacm
}

#----------------------------------------------------------------

w_metadata dsdmo dlls \
    title="MS dsdmo.dll" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/dsdmo.dll"

load_dsdmo()
{
    helper_directx_dl
    mkdir "$W_CACHE"/dsdmo   # kludge so test -f $file1 works

    w_try_cabextract -d "$W_TMP" -L -F dxnt.cab "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dsdmo.dll' "$W_TMP/dxnt.cab"
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dsdmoprp.dll' "$W_TMP/dxnt.cab"
    w_try_regsvr dsdmo.dll
    w_try_regsvr dsdmoprp.dll
}

#----------------------------------------------------------------

w_metadata dxsdk_nov2006 dlls \
    title="MS DirectX SDK, November 2006 (developers only)" \
    publisher="Microsoft" \
    year="2006" \
    media="download" \
    file1="dxsdk_aug2006.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/Microsoft DirectX SDK (August 2006)/Lib/x86/d3d10.lib"

load_dxsdk_nov2006()
{
    w_download http://download.microsoft.com/download/9/e/5/9e5bfc66-a621-4e0d-8bfe-6688058c3f00/dxsdk_aug2006.exe 1e9cdbef391ebfbf781e6c87a375138d8c195c57

    # dxview.dll uses mfc42u while registering
    w_call mfc42

    w_try_cabextract "$W_CACHE"/dxsdk_nov2006/dxsdk_aug2006.exe
    w_try_unzip "$W_TMP" dxsdk.exe
    cd "$W_TMP"
    w_try "$WINE" msiexec /i Microsoft_DirectX_SDK.msi $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata dxsdk_jun2010 dlls \
    title="MS DirectX SDK, June 2010 (developers only)" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="DXSDK_Jun10.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/Microsoft DirectX SDK (June 2010)/Lib/x86/d3d11.lib"

load_dxsdk_jun2010()
{
    w_download http://download.microsoft.com/download/A/E/7/AE743F1F-632B-4809-87A9-AA1BB3458E31/DXSDK_Jun10.exe 8fe98c00fde0f524760bb9021f438bd7d9304a69

    # Without dotnet20, install aborts halfway through
    w_call dotnet20

    cd "$W_TMP"
    w_try "$WINE" "$W_CACHE"/dxsdk_jun2010/DXSDK_Jun10.exe ${W_OPT_UNATTENDED:+/U}
}

#----------------------------------------------------------------

w_metadata dmsynth dlls \
    title="MS midi synthesizer from DirectX user redistributable" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/dmsynth.dll"

load_dmsynth()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F dxnt.cab "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dmsynth.dll' "$W_TMP/dxnt.cab"

    w_try_regsvr dmsynth.dll

    w_override_dlls native dmsynth
}

#----------------------------------------------------------------

w_metadata dotnet11 dlls \
    title="MS .NET 1.1" \
    publisher="Microsoft" \
    year="2003" \
    media="download" \
    conflicts="dotnet20 dotnet20sdk dotnet20sp1 dotnet20sp2 dotnet30 dotnet30sp1 dotnet35 dotnet35sp1 vjrun20" \
    file1="dotnetfx.exe" \
    installed_file1="c:/windows/Microsoft.NET/Framework/v1.1.4322/ndpsetup.ico"

load_dotnet11()
{
    if [ $W_ARCH = win64 ]
    then
        w_die "This package does not work on a 64-bit installation"
    fi

    # http://www.microsoft.com/downloads/details.aspx?FamilyId=262D25E3-F589-4842-8157-034D1E7CF3A3
    w_download http://download.microsoft.com/download/a/a/c/aac39226-8825-44ce-90e3-bf8203e74006/dotnetfx.exe 16a354a2207c4c8846b617cbc78f7b7c1856340e

    w_call remove_mono
    w_call corefonts
    w_call fontfix

    w_try cd "$W_CACHE/dotnet11"
    # Use builtin regsvcs.exe to work around https://bugs.winehq.org/show_bug.cgi?id=25120
    if test $W_OPT_UNATTENDED
    then
        WINEDLLOVERRIDES="regsvcs.exe=b" w_ahk_do "
            SetTitleMatchMode, 2
            run, dotnetfx.exe /q /C:\"install /q\"

            Loop
            {
                sleep 1000
                ifwinexist, Fatal error, Failed to delay load library
                {
                    WinClose, Fatal error, Failed to delay load library
                    continue
                }
                Process, exist, dotnetfx.exe
                dotnet_pid = %ErrorLevel%  ; Save the value immediately since ErrorLevel is often changed.
                if dotnet_pid = 0
                {
                    break
                }
            }
        "
    else
        WINEDLLOVERRIDES="regsvcs.exe=b" w_try "$WINE" dotnetfx.exe
    fi

    W_NGEN_CMD="w_try $WINE $DRIVE_C/windows/Microsoft.NET/Framework/v1.1.4322/ngen.exe executequeueditems"
}

verify_dotnet11()
{
    w_dotnet_verify dotnet11
}

#----------------------------------------------------------------

w_metadata dotnet11sp1 dlls \
    title="MS .NET 1.1 SP1" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="NDP1.1sp1-KB867460-X86.exe" \
    installed_file1="c:/windows/Microsoft.NET/Framework/v1.1.4322/CONFIG/web_hightrust.config.default"

load_dotnet11sp1()
{
    w_download http://download.microsoft.com/download/8/b/4/8b4addd8-e957-4dea-bdb8-c4e00af5b94b/NDP1.1sp1-KB867460-X86.exe 74a5b25d65a70b8ecd6a9c301a0aea10d8483a23

    w_call remove_mono
    w_call dotnet11

    w_try cd "$W_CACHE/dotnet11sp1"
    # Use builtin regsvcs.exe to work around http://bugs.winehq.org/show_bug.cgi?id=25120
    if test $W_OPT_UNATTENDED
    then
        WINEDLLOVERRIDES="regsvcs.exe=b" w_ahk_do "
            SetTitleMatchMode, 2
            run, NDP1.1sp1-KB867460-X86.exe /q /C:"install /q"

            Loop
            {
                sleep 1000
                ifwinexist, Fatal error, Failed to delay load library
                {
                    WinClose, Fatal error, Failed to delay load library
                    continue
                }
                Process, exist, dotnetfx.exe
                dotnet_pid = %ErrorLevel%  ; Save the value immediately since ErrorLevel is often changed.
                if dotnet_pid = 0
                {
                    break
                }
            }
        "
    else
        WINEDLLOVERRIDES="regsvcs.exe=b" w_try "$WINE" "$W_CACHE"/dotnet11sp1/NDP1.1sp1-KB867460-X86.exe
    fi

    W_NGEN_CMD="w_try $WINE $DRIVE_C/windows/Microsoft.NET/Framework/v1.1.4322/ngen.exe executequeueditems"
}

verify_dotnet11sp1()
{
    w_dotnet_verify dotnet11sp1
}

#----------------------------------------------------------------

w_metadata dotnet20 dlls \
    title="MS .NET 2.0" \
    publisher="Microsoft" \
    year="2006" \
    media="download" \
    conflicts="dotnet11" \
    file1="dotnetfx.exe" \
    installed_file1="c:/windows/Microsoft.NET/Framework/v2.0.50727/Microsoft .NET Framework 2.0/install.exe"

load_dotnet20()
{
    # http://www.microsoft.com/downloads/details.aspx?FamilyID=0856eacb-4362-4b0d-8edd-aab15c5e04f5
    w_download http://download.lenovo.com/ibmdl/pub/pc/pccbbs/thinkvantage_en/dotnetfx.exe a3625c59d7a2995fb60877b5f5324892a1693b2a

    w_call remove_mono
    w_call fontfix

    # Recipe from http://bugs.winehq.org/show_bug.cgi?id=10467#c57
    # and http://bugs.winehq.org/show_bug.cgi?id=30845#c10
    w_set_winver win2k

    # FIXME: verify on pristine Windows XP:
    if w_workaround_wine_bug 34803
    then
        "$WINE" reg delete 'HKLM\Software\Microsoft\.NETFramework\v2.0.50727\SBSDisabled' /f
    fi

    cd "$W_CACHE"/"$W_PACKAGE"
    w_try "$WINE" dotnetfx.exe ${W_OPT_UNATTENDED:+/q /c:"install.exe /q"}
    w_unset_winver

    # We can't stop installing dotnet20 in win2k mode until Wine supports
    # reparse/junction points
    # (see http://bugs.winehq.org/show_bug.cgi?id=10467#c57 )
    # so for now just remove the bogus msvc*80.dll files it installs.
    # See also http://bugs.winehq.org/show_bug.cgi?id=16577
    # This affects Victoria 2 demo, see http://forum.paradoxplaza.com/forum/showthread.php?p=11523967
    rm -f "$W_SYSTEM32_DLLS"/msvc?80.dll

    W_NGEN_CMD="w_try $WINE $DRIVE_C/windows/Microsoft.NET/Framework/v2.0.50727/ngen.exe executequeueditems"
}

verify_dotnet20()
{
    w_dotnet_verify dotnet20
}

#----------------------------------------------------------------

w_metadata dotnet20sdk dlls \
    title="MS .NET 2.0 SDK" \
    publisher="Microsoft" \
    year="2006" \
    media="download" \
    conflicts="dotnet11 dotnet20sp1 dotnet20sp2 dotnet30 dotnet40" \
    file1="setup.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/Microsoft.NET/SDK/v2.0/Bin/cordbg.exe"

load_dotnet20sdk()
{
    # http://www.microsoft.com/en-us/download/details.aspx?id=19988
    w_download http://download.microsoft.com/download/c/4/b/c4b15d7d-6f37-4d5a-b9c6-8f07e7d46635/setup.exe 4e4b1072b5e65e855358e2028403f2dc52a62ab4

    w_call remove_mono

    w_call dotnet20

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, setup.exe ${W_OPT_UNATTENDED:+/q /c:"install.exe /q"}

        Loop
        {
            sleep 1000
            ifwinexist, Microsoft Document Explorer, Application Data folder
            {
                WinClose, Microsoft Document Explorer, Application Data folder
                continue
            }
            ifwinexist, Microsoft CLR Debugger, Application Data folder
            {
                WinClose, Microsoft CLR Debugger, Application Data folder
                continue
            }
            ; FIXME: only appears if dotnet30sp1 is run first?
            ifwinexist, Microsoft .NET Framework 2.0 SDK Setup, This wizard will guide
            {
                ControlClick, Button22, Microsoft .NET Framework 2.0 SDK Setup
                Winwait, Microsoft .NET Framework 2.0 SDK Setup, By clicking
                sleep 100
                ControlClick, Button21
                sleep 100
                ControlClick, Button18
                WinWait, Microsoft .NET Framework 2.0 SDK Setup, Select from
                sleep 100
                ControlClick, Button12
                WinWait, Microsoft .NET Framework 2.0 SDK Setup, Type the path
                sleep 100
                ControlClick, Button8
                WinWait, Microsoft .NET Framework 2.0 SDK Setup, successfully installed
                sleep 100
                ControlClick, Button2
                sleep 100
            }
            Process, exist, setup.exe
            dotnet_pid = %ErrorLevel%
            if dotnet_pid = 0
            {
                break
            }
        }
    "

}

#----------------------------------------------------------------

w_metadata dotnet20sp1 dlls \
    title="MS .NET 2.0 SP1 (experimental)" \
    publisher="Microsoft" \
    year="2008" \
    media="download" \
    conflicts="dotnet11 dotnet20sp2 dotnet35sp1" \
    file1="NetFx20SP1_x86.exe" \
    installed_file1="c:/windows/winsxs/manifests/x86_Microsoft.VC80.CRT_1fc8b3b9a1e18e3b_8.0.50727.1433_x-ww_5cf844d2.cat"

load_dotnet20sp1()
{
    # FIXME: URL?
    w_download http://download.microsoft.com/download/0/8/c/08c19fa4-4c4f-4ffb-9d6c-150906578c9e/NetFx20SP1_x86.exe eef5a36924cdf0c02598ccf96aa4f60887a49840

    w_call remove_mono

    w_call dotnet20

    WINEDLLOVERRIDES=
    w_warn "Setting windows version so installer works"
    # Stop services
    # Recipe from http://bugs.winehq.org/show_bug.cgi?id=16956
    $WINESERVER -k
    # Fight a race condition, see bug 16956 comment 43
    w_set_winver win2k
    $WINESERVER -w
    WINEDLLOVERRIDES=ngen.exe,regsvcs.exe,mscorsvw.exe=b
    export WINEDLLOVERRIDES

    # FIXME: still needed?
    # Workaround Wine/Mono integration:
    "$WINE" reg add "HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\v2.0.50727" /v Version /t REG_SZ /d "2.0.50727" /f

    cd "$W_CACHE/$W_PACKAGE"
    "$WINE" NetFx20SP1_x86.exe ${W_OPT_UNATTENDED:+/q}
    status=$?

    case $status in
    0) ;;
    105) echo "exit status $status - normal, user selected 'restart now'" ;;
    194) echo "exit status $status - normal, user selected 'restart later'" ;;
    *) w_die "exit status $status - $W_PACKAGE installation failed" ;;
    esac

    # We can't stop installing dotnet20sp1 in win2k mode until Wine supports
    # reparse/junction points
    # (see http://bugs.winehq.org/show_bug.cgi?id=10467#c57 )
    # so for now just remove the bogus msvc*80.dll files it installs.
    # See also http://bugs.winehq.org/show_bug.cgi?id=16577
    # This affects Victoria 2 demo, see http://forum.paradoxplaza.com/forum/showthread.php?p=11523967
    rm -f "$W_SYSTEM32_DLLS"/msvc?80.dll

    w_unset_winver

    W_NGEN_CMD="w_try $WINE $DRIVE_C/windows/Microsoft.NET/Framework/v2.0.50727/ngen.exe executequeueditems"
}

verify_dotnet20sp1()
{
    w_dotnet_verify dotnet20sp1
}

#----------------------------------------------------------------

w_metadata dotnet20sp2 dlls \
    title="MS .NET 2.0 SP2 (experimental)" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    conflicts="dotnet11" \
    file1="NetFx20SP2_x86.exe" \
    installed_file1="c:/windows/winsxs/manifests/x86_Microsoft.VC80.CRT_1fc8b3b9a1e18e3b_8.0.50727.3053_x-ww_b80fa8ca.cat"

load_dotnet20sp2()
{
    # http://www.microsoft.com/downloads/details.aspx?familyid=5B2C0358-915B-4EB5-9B1D-10E506DA9D0F
    w_download http://download.microsoft.com/download/c/6/e/c6e88215-0178-4c6c-b5f3-158ff77b1f38/NetFx20SP2_x86.exe 22d776d4d204863105a5db99e8b8888be23c61a7

    w_call remove_mono

    w_call dotnet20

    # FIXME: verify on pristine Windows XP:
    if w_workaround_wine_bug 34803
    then
        "$WINE" reg delete 'HKLM\Software\Microsoft\.NETFramework\v2.0.50727\SBSDisabled' /f
    fi

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, NetFx20SP2_x86.exe ${W_OPT_UNATTENDED:+ /q /c:"install.exe /q"}

        Loop
        {
            sleep 1000
            ifwinexist,, cannot be uninstalled
            {
                WinClose,, cannot be uninstalled
                continue
            }
            Process, exist, NetFx20SP2_x86.exe
            dotnet_pid = %ErrorLevel%
            if dotnet_pid = 0
            {
                break
            }
        }
    "
    status=$?

    case $status in
    0) ;;
    105) echo "exit status $status - normal, user selected 'restart now'" ;;
    194) echo "exit status $status - normal, user selected 'restart later'" ;;
    *) w_die "exit status $status - $W_PACKAGE installation failed" ;;
    esac

    w_unset_winver

    W_NGEN_CMD="w_try $WINE $DRIVE_C/windows/Microsoft.NET/Framework/v2.0.50727/ngen.exe executequeueditems"
}

verify_dotnet20sp2()
{
    w_dotnet_verify dotnet20sp2
}

#----------------------------------------------------------------

w_metadata dotnet30 dlls \
    title="MS .NET 3.0" \
    publisher="Microsoft" \
    year="2006" \
    media="download" \
    conflicts="dotnet11 dotnet20sp1 dotnet20sp2 dotnet30sp1 dotnet35 dotnet35sp1 dotnet45 dotnet452" \
    file1="dotnetfx3.exe" \
    installed_file1="c:/windows/Microsoft.NET/Framework/v3.0/Microsoft .NET Framework 3.0/logo.bmp"

load_dotnet30()
{
    # http://msdn.microsoft.com/en-us/netframework/bb264589.aspx
    w_download http://download.microsoft.com/download/3/F/0/3F0A922C-F239-4B9B-9CB0-DF53621C57D9/dotnetfx3.exe f3d2c3c7e4c0c35450cf6dab1f9f2e9e7ff50039

    w_call remove_mono

    if test -f /proc/sys/kernel/yama/ptrace_scope
    then
        case `cat /proc/sys/kernel/yama/ptrace_scope` in
        0) ;;
        *) w_warn "If install fails, set /proc/sys/kernel/yama/ptrace_scope to 0.  See http://bugs.winehq.org/show_bug.cgi?id=30410" ;;
        esac
    fi

    case "$OS" in
    "Windows_NT")
        osver=`cmd /c ver`
        case "$osver" in
        *Version?6*) w_die "Vista and up bundle .NET 3.0, so you can't install it like this" ;;
        esac
        ;;
    esac

    w_call dotnet20

    w_warn "Installing .NET 3.0 runtime takes 3 minutes on a very fast machine, and the Finished dialog may hide in the taskbar."

    # AF's workaround to avoid long pause
    LANGPACKS_BASE_PATH="${W_WINDIR_UNIX}/SYSMSICache/Framework/v3.0"
    test -d "${LANGPACKS_BASE_PATH}" || mkdir -p "${LANGPACKS_BASE_PATH}"
    for lang in ar cs da de el es fi fr he it jp ko nb nl pl pt-BR pt-PT ru \
                sv tr zh-CHS zh-CHT
    do
        ln -sf "${W_SYSTEM32_DLLS}/spupdsvc.exe" "${LANGPACKS_BASE_PATH}/dotnetfx3langpack${lang}.exe"
    done

    w_set_winver winxp

    # Delete FontCache 3.0 service, it's in Wine for Mono, breaks native .NET
    # OK if this fails, that just means you have an older Wine.
    "$WINE" sc delete "FontCache3.0.0.0"

    WINEDLLOVERRIDES="ngen.exe,mscorsvw.exe=b;$WINEDLLOVERRIDES"

    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" $file1 ${W_OPT_UNATTENDED:+ /q /c:"install.exe /q"}

    # Doesn't install any ngen.exe
    # W_NGEN_CMD=""
}

verify_dotnet30()
{
    w_dotnet_verify dotnet30
}

#----------------------------------------------------------------

w_metadata dotnet30sp1 dlls \
    title="MS .NET 3.0 SP1" \
    publisher="Microsoft" \
    year="2007" \
    media="download" \
    conflicts="dotnet11 dotnet20sdk dotnet20sp1 dotnet20sp2" \
    file1="NetFx30SP1_x86.exe" \
    installed_file1="c:/windows/system32/XpsFilt.dll"    # we're cheating a bit here

load_dotnet30sp1()
{
    # FIXME: URL?
    w_download http://download.microsoft.com/download/8/F/E/8FEEE89D-9E4F-4BA3-993E-0FFEA8E21E1B/NetFx30SP1_x86.exe 8d779e337920b097aa0c01859912950606e9fc12
    # Recipe from http://bugs.winehq.org/show_bug.cgi?id=25060#c10
    w_download http://download.microsoft.com/download/2/5/2/2526f55d-32bc-410f-be18-164ba67ae07d/XPSEP%20XP%20and%20Server%202003%2032%20bit.msi 5d332ebd1025e294adafe72030fe33db707b2c82 "XPSEP XP and Server 2003 32 bit.msi"

    w_call remove_mono
    w_call dotnet30
    $WINESERVER -w
    w_call dotnet20sp1
    $WINESERVER -w

    cd "$W_CACHE/$W_PACKAGE"

    "$WINE" reg add "HKLM\\Software\\Microsoft\\Net Framework Setup\\NDP\\v3.0" /v Version /t REG_SZ /d "3.0" /f
    "$WINE" reg add "HKLM\\Software\\Microsoft-\\Net Framework Setup\\NDP\\v3.0" /v SP /t REG_DWORD /d 0001 /f

    w_try "$WINE" msiexec /i "XPSEP XP and Server 2003 32 bit.msi" ${W_UNATTENDED_SLASH_QB}
    "$WINE" sc delete FontCache3.0.0.0

    "$WINE" $file1 ${W_OPT_UNATTENDED:+/q}
    status=$?
    w_info $file1 exited with status $status

    # Doesn't install any ngen.exe
    # W_NGEN_CMD=""
}

verify_dotnet30sp1()
{
    w_dotnet_verify dotnet30sp1
}

#----------------------------------------------------------------

w_metadata dotnet35 dlls \
    title="MS .NET 3.5" \
    publisher="Microsoft" \
    year="2007" \
    media="download" \
    conflicts="dotnet11 dotnet20 dotnet20sdk dotnet20sp1 dotnet20sp2" \
    file1="dotnetfx35.exe" \
    installed_file1="c:/windows/Microsoft.NET/Framework/v3.5/MSBuild.exe"

load_dotnet35()
{
    case "$OS" in
    "Windows_NT") ;;
    *) w_warn "dotnet35 does not yet fully work or install on wine.  Caveat emptor." ;;
    esac

    # http://www.microsoft.com/downloads/details.aspx?FamilyId=333325FD-AE52-4E35-B531-508D977D32A6
    w_download http://download.microsoft.com/download/6/0/f/60fc5854-3cb8-4892-b6db-bd4f42510f28/dotnetfx35.exe 0a271bb44531aadef902829f98dfad66e4a57586

    w_call remove_mono

    w_call dotnet30sp1
    $WINESERVER -w

    if w_workaround_wine_bug 33450 "Installing msxml3"  ,1.5.28
    then
        w_call msxml3
    fi

    "$WINE" reg delete "HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\v3.5" /f

    # See also http://blogs.msdn.com/astebner/archive/2008/07/17/8745415.aspx
    cd "$W_TMP"
    w_try_cabextract $W_UNATTENDED_DASH_Q "$W_CACHE"/dotnet35/dotnetfx35.exe
    cd wcu/dotNetFramework
    "$WINE" dotNetFx35setup.exe /lang:ENU $W_UNATTENDED_SLASH_Q

    # Doesn't install any ngen.exe
    # W_NGEN_CMD=""
}

verify_dotnet35()
{
    w_dotnet_verify dotnet35
}

#----------------------------------------------------------------

w_metadata dotnet35sp1 dlls \
    title="MS .NET 3.5 SP1" \
    publisher="Microsoft" \
    year="2008" \
    media="download" \
    conflicts="dotnet11 dotnet20sp1 dotnet20sp2" \
    file1="dotnetfx35.exe" \
    installed_file1="c:/windows/Microsoft.NET/Framework/v3.5/Microsoft .NET Framework 3.5 SP1/logo.bmp"

load_dotnet35sp1()
{
    case "$OS" in
    "Windows_NT") ;;
    *) w_warn "dotnet35sp1 does not yet fully work or install on wine.  Caveat emptor." ;;
    esac

    # http://www.microsoft.com/download/en/details.aspx?id=25150
    w_download http://download.microsoft.com/download/2/0/e/20e90413-712f-438c-988e-fdaa79a8ac3d/dotnetfx35.exe 3dce66bae0dd71284ac7a971baed07030a186918

    w_call remove_mono

    w_call dotnet35
    $WINESERVER -w
    w_call dotnet20sp2
    $WINESERVER -w

    # Work around hang in http://bugs.winehq.org/show_bug.cgi?id=25060#c19
    WINEDLLOVERRIDES=ngen.exe,mscorsvw.exe=b
    export WINEDLLOVERRIDES

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, dotnetfx35.exe /lang:ENU $W_UNATTENDED_SLASH_Q

        Loop
        {
            sleep 1000
            ifwinexist,, cannot be uninstalled
            {
                WinClose,, cannot be uninstalled
                continue
            }
            Process, exist, dotnetfx35.exe
            dotnet_pid = %ErrorLevel%
            if dotnet_pid = 0
            {
                break
            }
        }
    "

    # Doesn't install any ngen.exe
    # W_NGEN_CMD=""
}

verify_dotnet35sp1()
{
    w_dotnet_verify dotnet35sp1
}

#----------------------------------------------------------------

w_metadata dotnet40 dlls \
    title="MS .NET 4.0" \
    publisher="Microsoft" \
    year="2011" \
    media="download" \
    conflicts="dotnet20sdk" \
    file1="dotNetFx40_Full_x86_x64.exe" \
    installed_file1="c:/windows/Microsoft.NET/Framework/v4.0.30319/ngen.exe"

load_dotnet40()
{
    if [ $W_ARCH = win64 ]
    then
        w_die "This package does not work on a 64-bit installation"
    fi

    case "$OS" in
        "Windows_NT") ;;
        *) w_warn "dotnet40 does not yet fully work or install on Wine.  Caveat emptor." ;;
    esac

    # http://www.microsoft.com/download/en/details.aspx?id=17718
    w_download http://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/dotNetFx40_Full_x86_x64.exe 58da3d74db353aad03588cbb5cea8234166d8b99

    w_call remove_mono

    # Remove Mono registry entry:
    "$WINE" reg delete "HKLM\Software\Microsoft\NET Framework Setup\NDP\v4" /f

    w_try rm -f "$W_WINDIR_UNIX/system32/mscoree.dll"

    cd "$W_CACHE/$W_PACKAGE"

    WINEDLLOVERRIDES=fusion=b "$WINE" dotNetFx40_Full_x86_x64.exe ${W_OPT_UNATTENDED:+/q /c:"install.exe /q"} || true

    w_override_dlls native mscoree

    "$WINE" reg add "HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\v4\\Full" /v Install /t REG_DWORD /d 0001 /f
    "$WINE" reg add "HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\v4\\Full" /v Version /t REG_SZ /d "4.0.30319" /f

    W_NGEN_CMD="$WINE $WINEPREFIX/drive_c/windows/Microsoft.NET/Framework/v4.0.30319/ngen.exe executequeueditems"
}

verify_dotnet40()
{
    w_dotnet_verify dotnet40
}

#----------------------------------------------------------------

w_metadata dotnet45 dlls \
    title="MS .NET 4.5" \
    publisher="Microsoft" \
    year="2012" \
    media="download" \
    conflicts="dotnet20 dotnet20sdk dotnet20sp1 dotnet20sp2 dotnet35sp1 dotnet40 vjrun20" \
    file1="dotnetfx45_full_x86_x64.exe" \
    installed_file1="c:/windows/Microsoft.NET/Framework/v4.0.30319/Microsoft.Windows.ApplicationServer.Applications.45.man"

load_dotnet45()
{
    if [ $W_ARCH = win64 ]
    then
        w_warn "This package may not work on a 64-bit installation"
    fi

    # http://www.microsoft.com/download/en/details.aspx?id=17718
    w_download http://download.microsoft.com/download/b/a/4/ba4a7e71-2906-4b2d-a0e1-80cf16844f5f/dotnetfx45_full_x86_x64.exe b2ff712ca0947040ca0b8e9bd7436a3c3524bb5d

    w_call remove_mono

    # Remove Mono registry entry:
    "$WINE" reg delete "HKLM\Software\Microsoft\NET Framework Setup\NDP\v4" /f

    w_try rm -f "$W_WINDIR_UNIX/system32/mscoree.dll"

    # See https://appdb.winehq.org/objectManager.php?sClass=version&iId=25478 for Focht's recipe
    w_call dotnet35
    w_call dotnet40
    w_set_winver win7

    cd "$W_CACHE/$W_PACKAGE"

    WINEDLLOVERRIDES=fusion=b "$WINE" dotnetfx45_full_x86_x64.exe ${W_OPT_UNATTENDED:+/q /c:"install.exe /q"}
    status=$?

    case $status in
        0) ;;
        105) echo "exit status $status - normal, user selected 'restart now'" ;;
        194) echo "exit status $status - normal, user selected 'restart later'" ;;
        *) w_die "exit status $status - $W_PACKAGE installation failed" ;;
    esac

    w_override_dlls native mscoree

    w_warn "Setting Windows version to 2003, otherwise applications using .NET 4.5 will subtly fail"
    w_set_winver win2k3
}

verify_dotnet45()
{
    w_dotnet_verify dotnet45
}

#----------------------------------------------------------------

w_metadata dotnet452 dlls \
    title="MS .NET 4.5.2" \
    publisher="Microsoft" \
    year="2012" \
    media="download" \
    conflicts="dotnet20 dotnet20sdk dotnet20sp1 dotnet20sp2 dotnet35sp1 dotnet40 dotnet45 vjrun20" \
    file1="dotnetfx45_full_x86_x64.exe" \
    installed_file1="c:/windows/Microsoft.NET/Framework/v4.0.30319/Microsoft.Windows.ApplicationServer.Applications.45.man"

load_dotnet452()
{
    if [ $W_ARCH = win64 ]
    then
        w_warn "This package may not work on a 64-bit installation"
    fi

    # http://www.microsoft.com/download/en/details.aspx?id=17718
    w_download http://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe 89f86f9522dc7a8a965facce839abb790a285a63

    w_call remove_mono

    # Remove Mono registry entry:
    "$WINE" reg delete "HKLM\Software\Microsoft\NET Framework Setup\NDP\v4" /f

    w_try rm -f "$W_WINDIR_UNIX/system32/mscoree.dll"

    # See https://appdb.winehq.org/objectManager.php?sClass=version&iId=25478 for Focht's recipe
    w_call dotnet35
    w_call dotnet40
    w_set_winver win7

    cd "$W_CACHE/$W_PACKAGE"

    WINEDLLOVERRIDES=fusion=b "$WINE" NDP452-KB2901907-x86-x64-AllOS-ENU.exe ${W_OPT_UNATTENDED:+/q /c:"install.exe /q"}
    status=$?

    case $status in
        0) ;;
        105) echo "exit status $status - normal, user selected 'restart now'" ;;
        194) echo "exit status $status - normal, user selected 'restart later'" ;;
        *) w_die "exit status $status - $W_PACKAGE installation failed" ;;
    esac

    w_override_dlls native mscoree

    w_warn "Setting Windows version to 2003, otherwise applications using .NET 4.5 will subtly fail"
    w_set_winver win2k3
}

verify_dotnet452()
{
    w_dotnet_verify dotnet452
}


#----------------------------------------------------------------

w_metadata dotnet_verifier dlls \
    title="MS .NET Verifier" \
    publisher="Microsoft" \
    year="2012" \
    media="download" \
    file1="netfx_5F00_setupverifier_5F00_new.zip" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/netfx_setupverifier.exe"

load_dotnet_verifier()
{
    # http://blogs.msdn.com/b/astebner/archive/2008/10/13/8999004.aspx
    # 2013/03/28: sha1sum 0eba832a0733cd47b7639463dd5a22a41e95ee6e
    # 2014/01/23: sha1sum 8818f3460826145e2a66bb91727afa7cd531037b
    # 2014/11/22: sha1sum 47de0b849c4c3d354df23588c709108e7816d788
    # 2015/07/31: sha1sum 32f24526a5716737281dc260451b60a641b23c7e
    # 2015/12/27: sha1sum b9712da2943e057668f21f68c473657a205c5cb8
    w_download http://blogs.msdn.com/cfs-file.ashx/__key/CommunityServer-Components-PostAttachments/00-08-99-90-04/netfx_5F00_setupverifier_5F00_new.zip b9712da2943e057668f21f68c473657a205c5cb8

    cd "$W_CACHE/$W_PACKAGE"
    w_try_unzip "$W_SYSTEM32_DLLS" netfx_5F00_setupverifier_5F00_new.zip netfx_setupverifier.exe
}

#----------------------------------------------------------------

w_metadata dxdiagn dlls \
    title="DirectX Diagnostic Library" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/dxdiagn.dll"

load_dxdiagn()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F dxnt.cab "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F dxdiagn.dll "$W_TMP/dxnt.cab"
    w_override_dlls native dxdiagn
}

#----------------------------------------------------------------

w_metadata dsound dlls \
    title="MS DirectSound from DirectX user redistributable" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/dsound.dll"

load_dsound()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F dxnt.cab "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'dsound.dll' "$W_TMP/dxnt.cab"

    w_try_regsvr dsound.dll

    w_override_dlls native dsound
}

#----------------------------------------------------------------

w_metadata esent dlls \
    title="MS Extensible Storage Engine" \
    publisher="Microsoft" \
    year="2011" \
    media="download" \
    file1="../win7sp1/windows6.1-KB976932-X86.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/esent.dll"

load_esent()
{
    helper_win7sp1 x86_microsoft-windows-e..estorageengine-isam_31bf3856ad364e35_6.1.7601.17514_none_f3ebb0cc8a4dd814/esent.dll
    w_try cp "$W_TMP/x86_microsoft-windows-e..estorageengine-isam_31bf3856ad364e35_6.1.7601.17514_none_f3ebb0cc8a4dd814/esent.dll" "$W_SYSTEM32_DLLS/esent.dll"

    w_override_dlls native,builtin esent
}

#----------------------------------------------------------------

# FIXME: update winetricks_is_installed to look at installed_file2..n
w_metadata flash dlls \
    title="Flash Player 14" \
    publisher="Adobe" \
    year="2014" \
    media="download" \
    file1="install_flash_player.exe" \
    file2="install_flash_player_ax.exe" \
    file3="flashplayer_14_sa.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/Macromed/Flash/FlashUtil32_14_0_0_179_Plugin.exe" \
    installed_file2="$W_SYSTEM32_DLLS_WIN/Macromed/Flash/FlashUtil32_14_0_0_176_ActiveX.exe" \
    installed_file3="$W_SYSTEM32_DLLS_WIN/Macromed/Flash/flashplayer_14_sa.exe" \
    homepage="http://www.adobe.com/products/flashplayer/"

load_flash()
{
    # As of July 9, 2013, Adobe Flash 10 is no longer supported.
    # And as of June 24, 2013, Adobe Flash 10.3 won't even install for me,
    # it tells you to go get a newer version!
    # See
    # http://blogs.adobe.com/psirt/
    # http://get.adobe.com/de/flashplayer/otherversions/
    # Now, we install older versions by using zipfiles at
    # http://helpx.adobe.com/flash-player/kb/archived-flash-player-versions.html

    # ActiveX plugin
    # 2013-03-28
    #w_download http://fpdownload.macromedia.com/get/flashplayer/pdc/11.6.602.180/install_flash_player_ax.exe 359f231d7007c17b419f777125e0f28fffc2e6a1
    # 2013-06-24
    # w_download http://fpdownload.macromedia.com/get/flashplayer/pdc/11.7.700.224/install_flash_player_ax.exe fdadce901fc7da7a175f71cc8f1f2dd0db78ec8e
    # 2014-01-21
    #w_download http://fpdownload.macromedia.com/get/flashplayer/pdc/12.0.0.38/install_flash_player_ax.exe 8deb33bcbbbbecfcbcbeb0f861d2c7492599da2b
    # 2014-08-17
    #w_download https://fpdownload.macromedia.com/get/flashplayer/pdc/14.0.0.176/install_flash_player_ax.exe 16231b509d8e689dc34ae36597d41c4fb1b3a67e
    # 2014-10-02
    w_download http://download.macromedia.com/pub/flashplayer/installers/archive/fp_14.0.0.176_archive.zip 40df72ab2c22bcd4442aa35eb586000776129982

    w_try_unzip "$W_TMP" "$W_CACHE"/flash/fp_14.0.0.176_archive.zip fp_14.0.0.176_archive/14_0_r0_176/flashplayer14_0r0_176_winax.exe
    cd "$W_TMP"/fp_14.0.0.176_archive/14_0_r0_176
    w_try "$WINE" flashplayer14_0r0_176_winax.exe ${W_OPT_UNATTENDED:+ /install}

    # Mozilla / Firefox (NPAPI) plugin
    # 2013-03-28
    #w_download http://fpdownload.macromedia.com/get/flashplayer/pdc/11.6.602.180/install_flash_player.exe bf44990ade52aa92078495ec39035d8489ff6e05
    # 2013-06-24
    #w_download http://fpdownload.macromedia.com/get/flashplayer/pdc/11.7.700.224/install_flash_player.exe 9c519fd5a7202c43b5713f9f6b083d970810112e
    # 2014-01-21
    #w_download http://fpdownload.macromedia.com/get/flashplayer/pdc/12.0.0.43/install_flash_player.exe 5a68f7aa21c4217cf801a46616fe724d601f773a
    # 2014-08-17
    #w_download https://fpdownload.macromedia.com/get/flashplayer/pdc/14.0.0.179/install_flash_player.exe 1d5725fd0d50eb1361213179ffae9ee24944755a
    # 2014-10-02
    w_download http://download.macromedia.com/pub/flashplayer/installers/archive/fp_14.0.0.179_archive.zip b94860ca0eff3e1420c24f9647a5f9f5e610ce34

    w_try_unzip "$W_TMP" "$W_CACHE"/flash/fp_14.0.0.179_archive.zip fp_14.0.0.179_archive/14_0_r0_179/flashplayer14_0r0_179_win.exe
    cd "$W_TMP"/fp_14.0.0.179_archive/14_0_r0_179
    w_try "$WINE" flashplayer14_0r0_179_win.exe ${W_OPT_UNATTENDED:+ /install}

    # Projector (standalone player)
    # 2015-07-06
    w_download http://download.macromedia.com/pub/flashplayer/updaters/14/flashplayer_14_sa.exe 62e5bc2e88b50091847408b9d473ee4a6c185167
    w_try cp "${W_CACHE}/${W_PACKAGE}/${file3}" "$W_SYSTEM32_DLLS/Macromed/Flash"

    # After updating the above, you should carry the following steps out by
    # hand to verify that plugin works.  (Ideally you'd also do it on
    # wine-1.5.6 to make sure the new version still uses vcrun2005 and
    # not something newer.)

    #    rm -rf ~/.cache/winetricks/flash
    #    cd ~/winetricks/src
    #    rm -rf ~/.wine
    #    sh winetricks -q flash ie7
    #    cd ~/".wine/drive_c/Program Files/Internet Explorer"
    #    wine iexplore.exe http://www.adobe.com/software/flash/about
    # Verify that the version of Flash shows up and that you're not prompted
    # to install Flash again
    #
    #    cd ~/winetricks/src
    #    rm -rf ~/.wine
    #    sh winetricks -q flash firefox
    #    cd ~/.wine/drive_c/Program\ Files/Mozilla\ Firefox
    #    wine firefox.exe http://www.adobe.com/software/flash/about
    # Verify that the version of Flash shows up and that you're not prompted
    # to install Flash again
}

#----------------------------------------------------------------

w_metadata gdiplus dlls \
    title="MS GDI+" \
    publisher="Microsoft" \
    year="2011" \
    media="download" \
    file1="../win7sp1/windows6.1-KB976932-X86.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/gdiplus.dll"

load_gdiplus()
{
    # gdiplus has changed in win7. See http://bugs.winehq.org/show_bug.cgi?id=32163#c3
    helper_win7sp1 x86_microsoft.windows.gdiplus_6595b64144ccf1df_1.1.7601.17514_none_72d18a4386696c80/gdiplus.dll
    w_try cp "$W_TMP/x86_microsoft.windows.gdiplus_6595b64144ccf1df_1.1.7601.17514_none_72d18a4386696c80/gdiplus.dll" "$W_SYSTEM32_DLLS/gdiplus.dll"

    # For some reason, native, builtin isn't good enough...?
    w_override_dlls native gdiplus
}

#----------------------------------------------------------------

w_metadata gdiplus_winxp dlls \
    title="MS GDI+" \
    publisher="Microsoft" \
    year="2004" \
    media="manual_download" \
    file1="NDP1.0sp2-KB830348-X86-Enu.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/gdiplus.dll"

load_gdiplus_winxp()
{
    w_download_manual http://download.cnet.com/NET-Framework-1-0-GDIPLUS-DLL-Security-Update/3000-10250_4-10732223.html NDP1.0sp2-KB830348-X86-Enu.exe 6113cd89d77525958295ccbd73b5fb8b89abd0aa
    cd "$W_CACHE/$W_PACKAGE"
    w_try_cabextract -d "$W_TMP" -F FL_gdiplus_dll_____X86.3643236F_FC70_11D3_A536_0090278A1BB8 "$W_CACHE/${W_PACKAGE}/$file1"
    w_try cp "$W_TMP/FL_gdiplus_dll_____X86.3643236F_FC70_11D3_A536_0090278A1BB8" "$W_SYSTEM32_DLLS/gdiplus.dll"

    # For some reason, native, builtin isn't good enough...?
    w_override_dlls native gdiplus
}

#----------------------------------------------------------------

w_metadata glidewrapper dlls \
    title="GlideWrapper" \
    publisher="Rolf Neuberger" \
    year="2005" \
    media="download" \
    file1="GlideWrapper084c.exe" \
    installed_file1="c:/windows/glide3x.dll"

load_glidewrapper()
{
    w_download http://www.zeckensack.de/glide/archive/GlideWrapper084c.exe 7a9d60a18b660473742b476465e9aea7bd5ab6f8
    cd "$W_CACHE/$W_PACKAGE"

    # The installer opens its README in a web browser, really annoying when doing make check/test:
    # FIXME: maybe we should back up this key first?
    if test ${W_OPT_UNATTENDED}
    then
        cat > "$W_TMP"/disable-browser.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\WineBrowser]
"Browsers"=""

_EOF_
        w_try_regedit "$W_TMP_WIN"\\disable-browser.reg

    fi

    # NSIS installer
    w_try "$WINE" $file1 ${W_OPT_UNATTENDED:+ /S}

    if test ${W_OPT_UNATTENDED}
    then
        "$WINE" reg delete "HKEY_CURRENT_USER\Software\Wine\WineBrowser" /v Browsers /f || true
    fi
}

#----------------------------------------------------------------

w_metadata gfw dlls \
    title="MS Games For Windows Live (xlive.dll)" \
    publisher="Microsoft" \
    year="2008" \
    media="download" \
    file1="gfwlivesetupmin.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/xlive.dll"

load_gfw()
{
    # http://www.microsoft.com/games/en-us/live/pages/livejoin.aspx
    # http://www.next-gen.biz/features/should-games-for-windows-live-die
    w_download http://download.microsoft.com/download/5/5/8/55846E20-4A46-4EF8-B272-7F988BC9090A/gfwlivesetupmin.exe 6f9e0ba052c68c8b51bb0e3ce6024d0e1c7b20b2

    # FIXME: Depends on .NET 20, but is it really needed? For now, skip it.
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" gfwlivesetupmin.exe /nodotnet $W_UNATTENDED_SLASH_Q

    w_call msasn1
}

#----------------------------------------------------------------

w_metadata glut dlls \
    title="The glut utility library for OpenGL" \
    publisher="Mark J. Kilgard" \
    year="2001" \
    media="download" \
    file1="glut-3.7.6-bin.zip" \
    installed_file1="c:/glut-3.7.6-bin/glut32.lib"

load_glut()
{
    w_download http://press.liacs.nl/researchdownloads/glut.win32/glut-3.7.6-bin.zip fb4731885c05b3cf2c79e85aabe8fc9949616ef4
    # FreeBSD unzip rm -rf's inside the target directory before extracting:
    w_try_unzip "$W_TMP" "$W_CACHE"/glut/glut-3.7.6-bin.zip
    w_try mv "$W_TMP/glut-3.7.6-bin" "$W_DRIVE_C"
    w_try cp "$W_DRIVE_C"/glut-3.7.6-bin/glut32.dll "$W_SYSTEM32_DLLS"
    w_warn "If you want to compile glut programs, add c:/glut-3.7.6-bin to LIB and INCLUDE"
}

#----------------------------------------------------------------

w_metadata gmdls dlls \
    title="General MIDI DLS Collection" \
    publisher="Microsoft / Roland" \
    year="1999" \
    media="download" \
    file1="../directx8/DX81Redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/drivers/gm.dls"

load_gmdls()
{
    w_download_to directx8 http://download.microsoft.com/download/whistler/Update/8.1/W982KMeXP/EN-US/DX81Redist.exe ea2345f602741343e97a5ece5d1d2c3cc44296c3

    w_try_unzip "$W_TMP" "$W_CACHE"/directx8/DX81Redist.exe "*/*/DirectX.cab"
    w_try_cabextract -d "$W_TMP" -F gm16.dls "$W_TMP"/*/*/DirectX.cab
    w_try mv "$W_TMP"/gm16.dls "$W_SYSTEM32_DLLS"/drivers/gm.dls
    if test "$W_ARCH" = "win64"
    then
        w_try cd "$W_SYSTEM64_DLLS"/drivers
        w_try ln -s ../../syswow64/drivers/gm.dls
    fi
}

#----------------------------------------------------------------
# um, codecs are kind of clustered here.  They probably deserve their own real category.

w_metadata allcodecs dlls \
    title="All codecs (dirac, ffdshow, icodecs, l3codecx, xvid) except wmp" \
    publisher="various" \
    year="1998-2009" \
    media="download"

load_allcodecs()
{
    w_call dirac
    w_call l3codecx
    w_call ffdshow
    w_call icodecs
    w_call xvid
}

#----------------------------------------------------------------

w_metadata dirac dlls \
    title="The Dirac directshow filter v1.0.2" \
    publisher="Dirac" \
    year="2009" \
    media="download" \
    file1="DiracDirectShowFilter-1.0.2.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/Dirac/DiracDecoder.dll"

load_dirac()
{
    w_download $WINETRICKS_SOURCEFORGE/dirac/DiracDirectShowFilter-1.0.2.exe c912d30a8fa500c7841444559feb1f49301611c4

    # Avoid mfc90 not found error.  (DiracSplitter-libschroedinger.ax needs mfc90 to register itself, I think.)
    w_call vcrun2008

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run DiracDirectShowFilter-1.0.2.exe
        WinWait, Dirac, Welcome
        if ( w_opt_unattended > 0 ) {
            ControlClick, Button2
            WinWait, Dirac, License
            ControlClick, Button2
            WinWait, Dirac, Location
            ControlClick, Button2
            WinWait, Dirac, Components
            ControlClick, Button2
            WinWait, Dirac, environment
            ControlCLick, Button1
            WinWait, Dirac, installed
            ControlClick, Button2
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata ffdshow dlls \
    title="ffdshow video codecs" \
    publisher="doom9 folks" \
    year="2010" \
    media="download" \
    file1="ffdshow_beta7_rev3154_20091209.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/ffdshow/ff_liba52.dll" \
    homepage="http://ffdshow-tryout.sourceforge.net"

load_ffdshow()
{
    w_download $WINETRICKS_SOURCEFORGE/ffdshow-tryout/ffdshow_beta7_rev3154_20091209.exe 8534c31489e51df70ee9583438d6211e6f0696d0
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" ffdshow_beta7_rev3154_20091209.exe $W_UNATTENDED_SLASH_SILENT
}

#----------------------------------------------------------------

w_metadata hid dlls \
    title="MS hid" \
    publisher="Microsoft" \
    year="2003" \
    media="download" \
    file1="../win2ksp4/W2KSP4_EN.EXE" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/hid.dll"

load_hid()
{
    helper_win2ksp4 i386/hid.dl_
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_TMP"/i386/hid.dl_

    w_override_dlls native hid
}

#----------------------------------------------------------------

w_metadata icodecs dlls \
    title="Indeo codecs" \
    publisher="Intel" \
    year="1998" \
    media="download" \
    file1="codinstl.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/ir50_32.dll"

load_icodecs()
{
    # Note: this codec is insecure, see
    # http://support.microsoft.com/kb/954157
    # Original source, ftp://download.intel.com/support/createshare/camerapack/codinstl.exe, had same checksum
    # 2010-11-14: http://codec.alshow.co.kr/Down/codinstl.exe
    # 2014-04-11: http://www.cucusoft.com/codecdownload/codinstl.exe (linked from http://www.cucusoft.com/codec.asp)
    w_download "http://www.cucusoft.com/codecdownload/codinstl.exe" 2c5d64f472abe3f601ce352dcca75b4f02996f8a

    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        SetTitleMatchMode, 2
        run codinstl.exe
        winwait, Welcome
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            controlclick, Button1  ; Next
            winwait, Software License Agreement
            sleep 1000
            controlclick, Button2  ; Yes
        }
        winwait, Setup Complete
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            controlclick, Button4  ; Finish
        }
        winwaitclose
    "

    # Work around bug in codec's installer?
    # http://support.britannica.com/other/touchthesky/win/issues/TSTUw_150.htm
    # http://appdb.winehq.org/objectManager.php?sClass=version&iId=7091
    w_try_regsvr ir50_32.dll
}

#----------------------------------------------------------------

w_metadata jet40 dlls \
    title="MS Jet 4.0 Service Pack 8" \
    publisher="Microsoft" \
    year="2003" \
    media="download" \
    file1="jet40sp8_9xnt.exe" \
    installed_file1="$W_COMMONFILES_X86_WIN/Microsoft Shared/dao/dao360.dll"

load_jet40()
{
    w_call mdac27
    w_call wsh57
    # http://support.microsoft.com/kb/239114
    # See also http://bugs.winehq.org/show_bug.cgi?id=6085
    # FIXME: "failed with error 2"
    w_download http://download.microsoft.com/download/4/3/9/4393c9ac-e69e-458d-9f6d-2fe191c51469/jet40sp8_9xnt.exe 8cd25342030857969ede2d8fcc34f3f7bcc2d6d4
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" jet40sp8_9xnt.exe $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata ie8_kb2936068 dlls \
    title="Cumulative Security Update for Internet Explorer 8" \
    publisher="Microsoft" \
    year="2014" \
    media="download" \
    file1="IE8-WindowsXP-KB2936068-x86-ENU.exe" \
    installed_file1="c:/windows/KB2936068-IE8.log"

load_ie8_kb2936068()
{
    w_call ie8

    w_download https://download.microsoft.com/download/3/8/C/38CE0ABB-01FD-4C0A-A569-BC5E82C34A17/IE8-WindowsXP-KB2936068-x86-ENU.exe 1bdeb741085b8f1ef6efc83f8615121373107347

    if [ $W_UNATTENDED_SLASH_Q ]
    then
        quiet="$W_UNATTENDED_SLASH_QUIET /forcerestart"
    else
        quiet=""
    fi

    cd "$W_CACHE"/"$W_PACKAGE"
    "$WINE" IE8-WindowsXP-KB2936068-x86-ENU.exe $quiet
    status=$?
    case $status in
        0|194) ;;
        *) w_die "$W_PACKAGE installation failed"
    esac
}

#----------------------------------------------------------------

w_metadata kde apps \
    title="KDE on Windows" \
    publisher="various" \
    year="2013" \
    media="download" \
    file1="kdewin-installer-gui-1.0.0.exe" \
    installed_exe1="$W_PROGRAMS_WIN/kde/etc/installer.ini" \
    homepage="http://windows.kde.org" \
    unattended="no"

load_kde()
{
    w_download http://mirrors.mit.edu/kde/stable/kdewin/installer/kdewin-installer-gui-1.0.0.exe 0d798facb7fbf11529e7ecd067e875d76adb9d78
    mkdir -p "$W_PROGRAMS_UNIX/kde"
    w_try cp "$W_CACHE/kde/${file1}" "$W_PROGRAMS_UNIX/kde"
    cd "$W_PROGRAMS_UNIX/kde"
    # There's no unattended option, probably because there are so many choices,
    # it's like Cygwin
    w_try "$WINE" "${file1}"
}

#----------------------------------------------------------------

w_metadata kindle apps \
    title="Amazon Kindle" \
    publisher="Amazon" \
    year="2016" \
    media="download" \
    file1="KindleForPC-installer-1.16.44025.exe" \
    installed_exe1="$W_PROGRAMS_WIN/Amazon/Kindle/Kindle.exe" \
    homepage="http://www.amazon.com/gp/feature.html/?docId=1000426311"

load_kindle()
{
    w_download http://kindleforpc.amazon.com/44025/KindleForPC-installer-1.16.44025.exe c57d0a7d8cd5f1c3020536edf336c3187f3e051f
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" $file1 ${W_OPT_UNATTENDED:+ /S}

    if w_workaround_wine_bug 35041
    then
        w_warn "You may need to run with taskset -c 0 to avoid a libX11 crash."
    fi
}

#----------------------------------------------------------------

w_metadata l3codecx dlls \
    title="MPEG Layer-3 Audio Codec for Microsoft DirectShow" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/l3codecx.ax"

load_l3codecx()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F dxnt.cab "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'l3codecx.ax' "$W_TMP/dxnt.cab"

    w_try_regsvr l3codecx.ax
}

#----------------------------------------------------------------

# FIXME: installed location is
# $W_PROGRAMS_X86_WIN/Gemeinsame Dateien/System/ADO/msado26.tlb
# in German... need a variable W_COMMONFILES or something like that

w_metadata mdac27 dlls \
    title="Microsoft Data Access Components 2.7 sp1" \
    publisher="Microsoft" \
    year="2006" \
    media="download" \
    file1="mdac_typ.exe" \
    installed_file1="$W_COMMONFILES_X86_WIN/System/ADO/msado26.tlb"

load_mdac27()
{
    if test $W_ARCH = win64
    then
        w_die "Installer doesn't support 64-bit architecture."
    fi

    # http://www.microsoft.com/downloads/en/details.aspx?FamilyId=9AD000F2-CAE7-493D-B0F3-AE36C570ADE8&displaylang=en
    w_download http://download.microsoft.com/download/3/b/f/3bf74b01-16ba-472d-9a8c-42b2b4fa0d76/mdac_typ.exe f68594d1f578c3b47bf0639c46c11c5da161feee
    load_native_mdac
    w_set_winver nt40
    cd "$W_CACHE"/"$W_PACKAGE"
    w_try "$WINE" mdac_typ.exe ${W_OPT_UNATTENDED:+ /q /C:"setup $W_UNATTENDED_SLASH_QNT"}
    w_unset_winver
}

#----------------------------------------------------------------

w_metadata mdac28 dlls \
    title="Microsoft Data Access Components 2.8 sp1" \
    publisher="Microsoft" \
    year="2005" \
    media="download" \
    file1="MDAC_TYP.EXE" \
    installed_file1="$W_COMMONFILES_X86_WIN/System/ADO/msado27.tlb"

load_mdac28()
{
    # http://www.microsoft.com/downloads/en/details.aspx?familyid=78cac895-efc2-4f8e-a9e0-3a1afbd5922e
    w_download http://download.microsoft.com/download/4/a/a/4aafff19-9d21-4d35-ae81-02c48dcbbbff/MDAC_TYP.EXE 4fbc272c79da59e38818924d8575accb0af776fb
    load_native_mdac
    w_set_winver nt40
    cd "$W_CACHE"/"$W_PACKAGE"
    w_try "$WINE" mdac_typ.exe ${W_OPT_UNATTENDED:+ /q /C:"setup $W_UNATTENDED_SLASH_QNT"}
    w_unset_winver
}

#----------------------------------------------------------------

w_metadata mdx dlls \
    title="Managed DirectX" \
    publisher="Microsoft" \
    year="2006" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="C:/windows/assembly/GAC/microsoft.directx/1.0.2902.0__31bf3856ad364e35/microsoft.directx.dll"

load_mdx()
{
    helper_directx_dl

    cd "$W_TMP"

    w_try_cabextract -F "*MDX*" "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -F "*.cab" *Archive.cab

    # Install assemblies
    w_try_cabextract -d "$W_WINDIR_UNIX/Microsoft.NET/DirectX for Managed Code/1.0.2902.0" -F "microsoft.directx*" *MDX1_x86.cab
    for file in mdx_*.cab
    do
        ver="${file%%_x86.cab}"
        ver="${ver##mdx_}"
        w_try_cabextract -d "$W_WINDIR_UNIX/Microsoft.NET/DirectX for Managed Code/$ver" -F "microsoft.directx*" "$file"
    done
    w_try_cabextract -d "$W_WINDIR_UNIX/Microsoft.NET/DirectX for Managed Code/1.0.2911.0" -F "microsoft.directx.direct3dx*" *MDX1_x86.cab

    # Add them to GAC
    cd "$W_WINDIR_UNIX/Microsoft.NET/DirectX for Managed Code"
    for ver in *
    do
        cd "$ver"
        for asm in *.dll
        do
            name="${asm%%.dll}"
            w_try mkdir -p "$W_WINDIR_UNIX/assembly/GAC/$name/${ver}__31bf3856ad364e35"
            w_try cp "$asm" "$W_WINDIR_UNIX/assembly/GAC/$name/${ver}__31bf3856ad364e35"
        done
        cd -
    done

    # AssemblyFolders
    cat > "$W_TMP"/asmfolders.reg <<_EOF_
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Microsoft\.NETFramework\AssemblyFolders\DX_1.0.2902.0]
@="C:\\\\windows\\\\Microsoft.NET\\\\DirectX for Managed Code\\\\1.0.2902.0\\\\"

[HKEY_LOCAL_MACHINE\Software\Microsoft\.NETFramework\AssemblyFolders\DX_1.0.2903.0]
@="C:\\\\windows\\\\Microsoft.NET\\\\DirectX for Managed Code\\\\1.0.2903.0\\\\"

[HKEY_LOCAL_MACHINE\Software\Microsoft\.NETFramework\AssemblyFolders\DX_1.0.2904.0]
@="C:\\\\windows\\\\Microsoft.NET\\\\DirectX for Managed Code\\\\1.0.2904.0\\\\"

[HKEY_LOCAL_MACHINE\Software\Microsoft\.NETFramework\AssemblyFolders\DX_1.0.2905.0]
@="C:\\\\windows\\\\Microsoft.NET\\\\DirectX for Managed Code\\\\1.0.2905.0\\\\"

[HKEY_LOCAL_MACHINE\Software\Microsoft\.NETFramework\AssemblyFolders\DX_1.0.2906.0]
@="C:\\\\windows\\\\Microsoft.NET\\\\DirectX for Managed Code\\\\1.0.2906.0\\\\"

[HKEY_LOCAL_MACHINE\Software\Microsoft\.NETFramework\AssemblyFolders\DX_1.0.2907.0]
@="C:\\\\windows\\\\Microsoft.NET\\\\DirectX for Managed Code\\\\1.0.2907.0\\\\"

[HKEY_LOCAL_MACHINE\Software\Microsoft\.NETFramework\AssemblyFolders\DX_1.0.2908.0]
@="C:\\\\windows\\\\Microsoft.NET\\\\DirectX for Managed Code\\\\1.0.2908.0\\\\"

[HKEY_LOCAL_MACHINE\Software\Microsoft\.NETFramework\AssemblyFolders\DX_1.0.2909.0]
@="C:\\\\windows\\\\Microsoft.NET\\\\DirectX for Managed Code\\\\1.0.2909.0\\\\"

[HKEY_LOCAL_MACHINE\Software\Microsoft\.NETFramework\AssemblyFolders\DX_1.0.2910.0]
@="C:\\\\windows\\\\Microsoft.NET\\\\DirectX for Managed Code\\\\1.0.2910.0\\\\"

[HKEY_LOCAL_MACHINE\Software\Microsoft\.NETFramework\AssemblyFolders\DX_1.0.2911.0]
@="C:\\\\windows\\\\Microsoft.NET\\\\DirectX for Managed Code\\\\1.0.2911.0\\\\"
_EOF_
    w_try_regedit "$W_TMP_WIN"\\asmfolders.reg
}

#----------------------------------------------------------------

w_metadata mf dlls \
    title="MS Media Foundation" \
    publisher="Microsoft" \
    year="2011" \
    media="download" \
    file1="../win7sp1/windows6.1-KB976932-X86.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/mf.dll"

load_mf()
{
    helper_win7sp1 x86_microsoft-windows-mediafoundation_31bf3856ad364e35_6.1.7601.17514_none_9e6699276b03c38e/mf.dll
    w_try cp "$W_TMP/x86_microsoft-windows-mediafoundation_31bf3856ad364e35_6.1.7601.17514_none_9e6699276b03c38e/mf.dll" "$W_SYSTEM32_DLLS/mf.dll"

    w_override_dlls native,builtin mf
}

#----------------------------------------------------------------

w_metadata mfc40 dlls \
    title="MS mfc40 (Microsoft Foundation Classes from Visual C++ 4.0)" \
    publisher="Microsoft" \
    year="1999" \
    media="download" \
    file1="mfc40.cab" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/mfc40.dll"

load_mfc40()
{
    w_download http://activex.microsoft.com/controls/vc/mfc40.cab 53c570e2c811674d6e4fa46cff5a3a04cd0ffc24
    w_try_cabextract -d "$W_TMP" "$W_CACHE"/mfc40/mfc40.cab
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -F *40.dll "$W_TMP"/mfc40.exe
}

#----------------------------------------------------------------

w_metadata mozillabuild apps \
    title="Mozilla build environment" \
    publisher="Mozilla Foundation" \
    year="2015" \
    media="download" \
    file1="MozillaBuildSetup-2.0.0.exe" \
    installed_file1="c:/mozilla-build/moztools/bin/nsinstall.exe" \
    homepage="https://wiki.mozilla.org/MozillaBuild"

load_mozillabuild()
{
    w_download http://ftp.mozilla.org/pub/mozilla.org/mozilla/libraries/win32/MozillaBuildSetup-2.0.0.exe daba4bc03ae9014c68611fd36b05dcc4083c6fdb
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" MozillaBuildSetup-2.0.0.exe $W_UNATTENDED_SLASH_S
}

#----------------------------------------------------------------

w_metadata msacm32 dlls \
    title="MS ACM32" \
    publisher="Microsoft" \
    year="2003" \
    media="download" \
    file1="../xpsp3/WindowsXP-KB936929-SP3-x86-ENU.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msacm32.dll"

load_msacm32()
{
    helper_xpsp3 i386/msacm32.dl_
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_TMP"/i386/msacm32.dl_
    w_override_dlls native,builtin msacm32
}

#----------------------------------------------------------------

w_metadata msasn1 dlls \
    title="MS ASN1" \
    publisher="Microsoft" \
    year="2003" \
    media="download" \
    file1="../win2ksp4/W2KSP4_EN.EXE" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msasn1.dll"

load_msasn1()
{
    helper_win2ksp4 i386/msasn1.dl_
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_TMP"/i386/msasn1.dl_
}

#----------------------------------------------------------------

w_metadata msctf dlls \
    title="MS Text Service Module" \
    publisher="Microsoft" \
    year="2003" \
    media="download" \
    file1="../xpsp3/WindowsXP-KB936929-SP3-x86-ENU.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msctf.dll"

load_msctf()
{
    helper_xpsp3 i386/msctf.dl_
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_TMP"/i386/msctf.dl_
    w_override_dlls native,builtin msctf
}

#----------------------------------------------------------------

w_metadata msdxmocx dlls \
    title="MS Windows Media Player 2 ActiveX control for VB6" \
    publisher="Microsoft" \
    year="1999" \
    media="download" \
    file1="mpfull.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msdxm.ocx"

load_msdxmocx()
{
    # Previously at http://www.oldapps.com/windows_media_player.php?old_windows_media_player=3?download
    # (2015/12/01) Iceweasel gave a security warning (!), but clamscan and virustotal.com report it as clean
    #
    # (2016/02/18) Since then, oldapps.com removed it. It's on a Finnish mirror, where it's been since 2001/10/20
    # Found using http://www.filewatcher.com/m/mpfull.exe.3593680-0.html
    # The sha1sum is different. Perhaps Iceweasel was right. This one is also clean according to clamscan/virustotal.com

    w_download ftp://www.define.fi/Pub/Fixes/Microsoft/Windows%2095/mpfull.exe 99691df6ac455233230faac7514bdea781ba0ce3

    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_CACHE/$W_PACKAGE/${file1}"
    w_try_regsvr msdxm.ocx
}

#----------------------------------------------------------------

w_metadata msflxgrd dlls \
    title="MS FlexGrid Control (msflxgrd.ocx)" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="MsFlxGrd.cab" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/MSFLXGRD.OCX"

load_msflxgrd()
{
    # http://msdn.microsoft.com/en-us/library/aa240864(VS.60).aspx
    # may 2011: f497c3b390cd80d5bcd1f13d5c0c68b206369aa7
    # 2015/11/09: Removed from Microsoft.com, archive.org has an older copy:
    # 2015/11/09: 3d6c04e923781d4ce0d3ab62189b8de352ab25d5
    w_download http://activex.microsoft.com/controls/vb6/MsFlxGrd.cab 3d6c04e923781d4ce0d3ab62189b8de352ab25d5

    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/msflxgrd/${file1}
    w_try cp -f "$W_TMP"/[Mm][Ss][Ff][Ll][Xx][Gg][Rr][Dd].[Oo][Cc][Xx] "$W_SYSTEM32_DLLS"
    w_try_regsvr MSFLXGRD.OCX
}

#----------------------------------------------------------------

w_metadata mshflxgd dlls \
    title="MS Hierarchical FlexGrid Control (mshflxgd.ocx)" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="MSHFLXGD.CAB" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/MSHFLXGD.OCX"

load_mshflxgd()
{
    # http://msdn.microsoft.com/en-us/library/aa240864(VS.60).aspx
    # orig: 5f9c7a81022949bfe39b50f2bbd799c448bb7377
    # Jan 2009: 7ad74e589d5eefcee67fa14e65417281d237a6b6
    # May 2009: bd8aa796e16e5f213414af78931e0379d9cbe292
    # 2015/11/09: Removed from Microsoft.com, archive.org has the original copy:
    # 2015/11/09: 5f9c7a81022949bfe39b50f2bbd799c448bb7377
    w_download http://activex.microsoft.com/controls/vb6/MSHFLXGD.CAB 5f9c7a81022949bfe39b50f2bbd799c448bb7377

    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/mshflxgd/MSHFLXGD.CAB
    w_try cp -f "$W_TMP"/[Mm][Ss][Hh][Ff][Ll][Xx][Gg][Dd].[Oo][Cc][Xx] "$W_SYSTEM32_DLLS"
    w_try_regsvr MSHFLXGD.OCX
}

#----------------------------------------------------------------

w_metadata mspatcha dlls \
    title="MS mspatcha" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="../win2ksp4/W2KSP4_EN.EXE" \
    installed_exe1="$W_SYSTEM32_DLLS_WIN/mspatcha.dll"

load_mspatcha()
{
    helper_win2ksp4 i386/mspatcha.dl_
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_TMP"/i386/mspatcha.dl_

    w_override_dlls native,builtin mspatcha
}

#----------------------------------------------------------------

w_metadata msscript dlls \
    title="MS Windows Script Control" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="sct10en.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msscript.ocx"

load_msscript()
{
    # http://msdn.microsoft.com/scripting/scriptcontrol/x86/sct10en.exe
    # http://www.microsoft.com/downloads/details.aspx?familyid=d7e31492-2595-49e6-8c02-1426fec693ac
    w_download http://download.microsoft.com/download/d/2/a/d2a7430c-6d5b-48e9-96c4-3c751be7bffe/sct10en.exe fd9f2f23357ab11ae70682d6864f7e9f188adf2a

    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/msscript/sct10en.exe
    w_try cp -f "$W_TMP"/msscript.ocx "$W_SYSTEM32_DLLS"
    w_try_regsvr msscript.ocx
}
#----------------------------------------------------------------

w_metadata msls31 dlls \
    title="MS Line Services" \
    publisher="Microsoft" \
    year="2001" \
    media="download" \
    file1="InstMsiW.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msls31.dll"

load_msls31()
{
    # Needed by native RichEdit and Internet Explorer
    w_download http://download.microsoft.com/download/WindowsInstaller/Install/2.0/NT45/EN-US/InstMsiW.exe 4fc3bf0dc96b5cf5ab26430fac1c33c5c50bd142
    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/msls31/InstMsiW.exe
    w_try cp -f "$W_TMP"/msls31.dll "$W_SYSTEM32_DLLS"
}

#----------------------------------------------------------------

w_metadata msmask dlls \
    title="MS Masked Edit Control" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="MSMASK32.CAB" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msmask32.ocx"

load_msmask()
{
    # http://msdn.microsoft.com/en-us/library/11405hcf(VS.71).aspx
    # http://bugs.winehq.org/show_bug.cgi?id=2934
    # old: 3c6b26f68053364ea2e09414b615dbebafb9d5c3
    # May 2009: 30e55679e4a13fe4d9620404476f215f93239292
    # 2015/11/09: Removed from microsoft.com, archive.org has an older copy:
    # 2015/11/09: bdd2bb3a32d18926a048f302aff18b1e6d250d9d
    w_download http://activex.microsoft.com/controls/vb6/MSMASK32.CAB bdd2bb3a32d18926a048f302aff18b1e6d250d9d
    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/msmask/MSMASK32.CAB
    w_try cp -f "$W_TMP"/[Mm][Ss][Mm][Aa][Ss][Kk]32.[Oo][Cc][Xx] "$W_SYSTEM32_DLLS"/msmask32.ocx
    w_try_regsvr msmask32.ocx
}

 #----------------------------------------------------------------

w_metadata msftedit dlls \
    title="Microsoft RichEdit Control" \
    publisher="Microsoft" \
    year="2011" \
    media="download" \
    file1="../win7sp1/windows6.1-KB976932-X86.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msftedit.dll"

load_msftedit()
{
    helper_win7sp1 x86_microsoft-windows-msftedit_31bf3856ad364e35_6.1.7601.17514_none_d7d862f19573a5ff/msftedit.dll
    w_try cp "$W_TMP/x86_microsoft-windows-msftedit_31bf3856ad364e35_6.1.7601.17514_none_d7d862f19573a5ff/msftedit.dll" "$W_SYSTEM32_DLLS/msftedit.dll"

    w_override_dlls native,builtin mstfedit
}

#----------------------------------------------------------------

w_metadata msxml3 dlls \
    title="MS XML Core Services 3.0" \
    publisher="Microsoft" \
    year="2005" \
    media="download" \
    file1="msxml3.msi" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msxml3.dll"

load_msxml3()
{
    # Service Pack 5
    #w_download http://download.microsoft.com/download/a/5/e/a5e03798-2454-4d4b-89a3-4a47579891d8/msxml3.msi
    # Service Pack 7
    w_download http://download.microsoft.com/download/8/8/8/888f34b7-4f54-4f06-8dac-fa29b19f33dd/msxml3.msi d4c2178dfb807e1a0267fce0fd06b8d51106d913

    # It won't install on top of Wine's msxml3, which has a pretty high version number, so delete Wine's fake DLL
    rm "$W_SYSTEM32_DLLS"/msxml3.dll
    w_override_dlls native msxml3
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" msiexec /i msxml3.msi $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata msxml4 dlls \
    title="MS XML Core Services 4.0" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="msxml.msi" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msxml4.dll"

load_msxml4()
{
    # MS06-071: http://www.microsoft.com/downloads/details.aspx?familyid=24B7D141-6CDF-4FC4-A91B-6F18FE6921D4
    # w_download http://download.microsoft.com/download/e/2/e/e2e92e52-210b-4774-8cd9-3a7a0130141d/msxml4-KB927978-enu.exe d364f9fe80c3965e79f6f64609fc253dfeb69c25
    # MS07-042: http://www.microsoft.com/downloads/details.aspx?FamilyId=021E12F5-CB46-43DF-A2B8-185639BA2807
    # w_download http://download.microsoft.com/download/9/4/2/9422e6b6-08ee-49cb-9f05-6c6ee755389e/msxml4-KB936181-enu.exe 73d75d7b41f8a3d49f272e74d4f73bb5e82f1acf
    # SP3 (2009): http://www.microsoft.com/downloads/details.aspx?familyid=7F6C0CB4-7A5E-4790-A7CF-9E139E6819C0
    w_download http://download.microsoft.com/download/A/2/D/A2D8587D-0027-4217-9DAD-38AFDB0A177E/msxml.msi aa70c5c1a7a069af824947bcda1d9893a895318b
    w_override_dlls native,builtin msxml4
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" msiexec /i msxml.msi $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata msxml6 dlls \
    title="MS XML Core Services 6.0 sp1" \
    publisher="Microsoft" \
    year="2007" \
    media="download" \
    file1="msxml6_x86.msi" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msxml6.dll"

load_msxml6()
{
    # Service Pack 1
    # http://www.microsoft.com/downloads/details.aspx?familyid=D21C292C-368B-4CE1-9DAB-3E9827B70604
    if [ $W_ARCH = win64 ]
    then
        w_download http://download.microsoft.com/download/e/a/f/eafb8ee7-667d-4e30-bb39-4694b5b3006f/msxml6_x64.msi ca0c0814a9c7024583edb997296aad7cb0a3cbf7
    else
        w_download http://download.microsoft.com/download/e/a/f/eafb8ee7-667d-4e30-bb39-4694b5b3006f/msxml6_x86.msi 5125220e985b33c946bbf9f60e2b222c7570bfa2
    fi
    w_override_dlls native,builtin msxml6
    rm -f "$W_SYSTEM32_DLLS/msxml6.dll"
    if [ $W_ARCH = win64 ]
    then
        rm -f "$W_SYSTEM64_DLLS/msxml6.dll"
        w_try_msiexec64 /i "$W_CACHE"/msxml6/msxml6_x64.msi
    else
        w_try "$WINE" msiexec /i "$W_CACHE"/msxml6/msxml6_x86.msi $W_UNATTENDED_SLASH_Q
    fi
}

#----------------------------------------------------------------

w_metadata nuget dlls \
    title="NuGet Package manager" \
    publisher="Outercurve Foundation" \
    year="2013" \
    media="download" \
    file1="nuget.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/nuget.exe" \
    homepage="https://nuget.org"

load_nuget()
{
    w_call dotnet40
    # 2014-01-22: d4082afc4f89df195fa1e83ee1cf02bce3dd2f13
    # 2014-02-26: 9bc98ced9c2d2b51ab687f86b5580913c025b8b0
    # 2014-04-17: 3210cc9a2e575384d59b0604c892bccce760e9b6
    # probably changes too rapidly to check
    w_download https://nuget.org/nuget.exe
    w_try cp "$W_CACHE/$W_PACKAGE"/nuget.exe "$W_SYSTEM32_DLLS"
    w_warn "To run NuGet, use the command line \"$WINE nuget\"."
}

#----------------------------------------------------------------

w_metadata ogg dlls \
    title="OpenCodecs 0.85: FLAC, Speex, Theora, Vorbis, WebM" \
    publisher="Xiph.Org Foundation" \
    year="2011" \
    media="download" \
    file1="opencodecs_0.85.17777.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/Xiph.Org/Open Codecs/AxPlayer.dll" \
    homepage="http://xiph.org/dshow"

load_ogg()
{
    w_download http://downloads.xiph.org/releases/oggdsf/opencodecs_0.85.17777.exe 386cf7cd29ffcbf8705eff8c8233de448ecf33ab
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" $file1 $W_UNATTENDED_SLASH_S
}

#----------------------------------------------------------------

w_metadata ollydbg110 apps \
    title="OllyDbg" \
    publisher="ollydbg.de" \
    year="2004" \
    media="download" \
    file1="odbg110.zip" \
    installed_file1="c:/ollydbg110/OLLYDBG.EXE" \
    homepage="http://ollydbg.de"

load_ollydbg110()
{
    # The GUI is unreadable without having corefonts installed.
    w_call corefonts

    w_download http://www.ollydbg.de/odbg110.zip 8403d8049a0841887c16cf64889596ad52b84da8
    w_try_unzip "$W_DRIVE_C/ollydbg110" "$W_CACHE/$W_PACKAGE"/odbg110.zip
}

#----------------------------------------------------------------

w_metadata ollydbg200 apps \
    title="OllyDbg" \
    publisher="ollydbg.de" \
    year="2010" \
    media="download" \
    file1="odbg200.zip" \
    installed_file1="c:/ollydbg200/ollydbg.exe" \
    homepage="http://ollydbg.de"

load_ollydbg200()
{
    # The GUI is unreadable without having corefonts installed.
    w_call corefonts

    w_download http://www.ollydbg.de/odbg200.zip 68e572d94a0555e8f14516b55b6b96b879900fe9
    w_try_unzip "$W_DRIVE_C/ollydbg200" "$W_CACHE/$W_PACKAGE"/odbg200.zip
}

#----------------------------------------------------------------

w_metadata ollydbg201 apps \
    title="OllyDbg" \
    publisher="ollydbg.de" \
    year="2013" \
    media="download" \
    file1="odbg201.zip" \
    installed_file1="c:/ollydbg201/ollydbg.exe" \
    homepage="http://ollydbg.de"

load_ollydbg201()
{
    # The GUI is unreadable without having corefonts installed.
    w_call corefonts

    w_download http://www.ollydbg.de/odbg201.zip d41fe77a2801d38476f20468ab61ddce14c3abb8
    w_try_unzip "$W_DRIVE_C/ollydbg201" "$W_CACHE/$W_PACKAGE"/odbg201.zip

    # ollydbg201 is affected by Wine bug 36012 if debug symbols are available.
    # As a workaround native 'dbghelp' can be installed. We don't do this automatically
    # because for some people it might work even without additional workarounds.
    # Older versions of OllyDbg were not affected by this bug.
}

#----------------------------------------------------------------

w_metadata openwatcom apps \
    title="Open Watcom C/C++ compiler (can compile win16 code!)" \
    publisher="Watcom" \
    year="2010" \
    media="download" \
    file1="open-watcom-c-win32-1.9.exe" \
    installed_file1="c:/WATCOM/owsetenv.bat" \
    homepage="http://www.openwatcom.org"

load_openwatcom()
{
    # 2016/03/11: upstream http://www.openwatcom.org appears to be dead (404)
    w_download "http://openwatcom.mirror.fr/open-watcom-c-win32-1.9.exe" 236ac33ebd463006be4ecd83d7ebea1c026eb55a

    if [ $W_UNATTENDED_SLASH_Q ]
    then
        # Options documented at http://bugzilla.openwatcom.org/show_bug.cgi?id=898
        # But they don't seem to work on Wine, so jam them into setup.inf
        # Pick smallest installation that supports 16-bit C and C++
        cd "$W_TMP"
        cp "$W_CACHE"/openwatcom/open-watcom-c-win32-1.9.exe .
        w_try_unzip . open-watcom-c-win32-1.9.exe setup.inf
        sed -i 's/tools16=.*/tools16=true/' setup.inf
        w_try zip -f open-watcom-c-win32-1.9.exe
        w_try "$WINE" open-watcom-c-win32-1.9.exe -s
    else
        cd "$W_CACHE/$W_PACKAGE"
        w_try "$WINE" open-watcom-c-win32-1.9.exe
    fi

    if test ! -f "$W_DRIVE_C"/WATCOM/binnt/wcc.exe
    then
        w_warn "c:/watcom/binnt/wcc.exe not found; you probably didn't select 16-bit tools, and won't be able to build win16test."
    fi
}

#----------------------------------------------------------------

w_metadata pdh dlls \
    title="MS pdh.dll (Performance Data Helper)" \
    publisher="Microsoft" \
    year="2001" \
    media="download" \
    file1="pdhinst.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/pdh.dll"

load_pdh()
{
    # http://support.microsoft.com/kb/284996
    w_download http://download.microsoft.com/download/platformsdk/Redist/5.0.2195.2668/NT4/EN-US/pdhinst.exe f42448660def8cd7f42b34aa7bc7264745f4425e

    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/pdh/pdhinst.exe
    w_try_unzip "$W_TMP" "$W_TMP"/pdh.exe
    w_try cp -f "$W_TMP"/x86/Pdh.Dll "$W_SYSTEM32_DLLS"/pdh.dll
}

#----------------------------------------------------------------

w_metadata physx dlls \
    title="PhysX" \
    publisher="Nvidia" \
    year="2014" \
    media="download" \
    file1="PhysX-9.14.0702-SystemSoftware.msi" \
    installed_file1="$W_PROGRAMS_WIN/NVIDIA Corporation/PhysX/Engine/v2.8.3/PhysXCore.dll"

load_physx()
{
    # Has a minor issue, see bug report http://bugs.winehq.org/show_bug.cgi?id=34167
    w_download http://uk.download.nvidia.com/Windows/9.14.0702/PhysX-9.14.0702-SystemSoftware.msi 81e2d38e2356e807ad80cdf150ed5acfff839c8b
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" msiexec /i PhysX-9.14.0702-SystemSoftware.msi $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata pngfilt dlls \
    title="pngfilt.dll (from ie5)" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="IE5.01sp4-KB871260-Windows2000sp4-x86-ENU.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/pngfilt.dll"

load_pngfilt()
{
    # http://www.microsoft.com/en-us/download/details.aspx?id=3907
    w_download http://download.microsoft.com/download/5/0/c/50c42d0e-07a8-4a2b-befb-1a403bd0df96/IE5.01sp4-KB871260-Windows2000sp4-x86-ENU.exe 6f5db296ebf58e81c49bc667049a3f88a3f1ec3d
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F pngfilt.dll "$W_CACHE"/pngfilt/IE5.01sp4-KB871260-Windows2000sp4-x86-ENU.exe
    w_try_regsvr pngfilt.dll
}

#----------------------------------------------------------------

w_metadata qdvd dlls \
    title="qdvd.dll (from DirectX 9 user redistributable)" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/qdvd.dll"

load_qdvd()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F dxnt.cab "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F qdvd.dll "$W_TMP/dxnt.cab"

    w_try_regsvr qdvd.dll

    w_override_dlls native qdvd
}

#----------------------------------------------------------------

w_metadata quartz dlls \
    title="quartz.dll (from Directx 9 user redistributable)" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/quartz.dll"

load_quartz()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F dxnt.cab "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F quartz.dll "$W_TMP/dxnt.cab"

    w_try_regsvr quartz.dll

    w_override_dlls native quartz
}

#----------------------------------------------------------------

w_metadata quicktime72 dlls \
    title="Apple QuickTime 7.2" \
    publisher="Apple" \
    year="2010" \
    media="download" \
    file1="QuickTimeInstaller.exe" \
    installed_file1="c:/windows/Installer/{95A890AA-B3B1-44B6-9C18-A8F7AB3EE7FC}/QTPlayer.ico"

load_quicktime72()
{
    # https://support.apple.com/downloads/quicktime
    w_download http://appldnld.apple.com.edgesuite.net/content.info.apple.com/QuickTime/061-2915.20070710.pO94c/QuickTimeInstaller.exe bb89981f10cf21de57b9453e53cf81b9194271a9

    cd "$W_CACHE"/"$W_PACKAGE"
    w_try "$WINE" ${file1} ALLUSERS=1 DESKTOP_SHORTCUTS=0 QTTaskRunFlags=0 QTINFO.BISQTPRO=1 SCHEDULE_ASUW=0 REBOOT_REQUIRED=No $W_UNATTENDED_SLASH_QN > /dev/null 2>&1

    if w_workaround_wine_bug 11681
    then
        # Following advice verified with test movies from
        # http://support.apple.com/kb/HT1425
        # in QuickTimePlayer.

        w_warn "In Quicktime preferences, check Advanced / Safe Mode (gdi), or movies won't play."
        if test "$W_UNATTENDED_SLASH_Q" = ""
        then
            w_try "$WINE" control "$W_PROGRAMS_WIN\\QuickTime\\QTSystem\\QuickTime.cpl"
        else
            # FIXME: script the control panel with AutoHotKey?
            # We could probably also overwrite QuickTime.qtp but
            # the format isn't known, so we'd have to override all other settings, too.
            :
        fi
    fi
}

#----------------------------------------------------------------

w_metadata quicktime76 dlls \
    title="Apple QuickTime 7.6" \
    publisher="Apple" \
    year="2010" \
    media="download" \
    file1="QuickTimeInstaller.exe" \
    installed_file1="c:/windows/Installer/{57752979-A1C9-4C02-856B-FBB27AC4E02C}/QTPlayer.ico"

load_quicktime76()
{
    # http://www.apple.com/quicktime/download/
    w_download http://appldnld.apple.com/QuickTime/041-0025.20101207.Ptrqt/QuickTimeInstaller.exe 1eec8904f041d9e0ad3459788bdb690e45dbc38e

    cd "$W_CACHE"/"$W_PACKAGE"
    w_try "$WINE" QuickTimeInstaller.exe ALLUSERS=1 DESKTOP_SHORTCUTS=0 QTTaskRunFlags=0 QTINFO.BISQTPRO=1 SCHEDULE_ASUW=0 REBOOT_REQUIRED=No $W_UNATTENDED_SLASH_QN > /dev/null 2>&1

    if w_workaround_wine_bug 11681
    then
        # Following advice verified with test movies from
        # http://support.apple.com/kb/HT1425
        # in QuickTimePlayer.

        w_warn "In Quicktime preferences, check Advanced / Safe Mode (gdi), or movies won't play."
        if test "$W_UNATTENDED_SLASH_Q" = ""
        then
            w_try "$WINE" control "$W_PROGRAMS_WIN\\QuickTime\\QTSystem\\QuickTime.cpl"
        else
            # FIXME: script the control panel with AutoHotKey?
            # We could probably also overwrite QuickTime.qtp but
            # the format isn't known, so we'd have to override all other settings, too.
            :
        fi
    fi
}

#----------------------------------------------------------------

w_metadata remove_mono settings \
    title_uk="Видалити вбудоване wine-mono" \
    title="Remove builtin wine-mono"

load_remove_mono()
{
    # FIXME: fold other .NET cleanups here (registry entries).
    # Probably should only do that for wine >= 1.5.6
    mono_uuid="`$WINE uninstaller --list | grep Mono | cut -f1 -d\|`"
    if test "$mono_uuid"
    then
         "$WINE" uninstaller --remove $mono_uuid
    else
        w_warn "Mono does not appear to be installed."
    fi
}

#----------------------------------------------------------------

w_metadata riched20 dlls \
    title="MS RichEdit Control 2.0 (riched20.dll)" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="../win2ksp4/W2KSP4_EN.EXE" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/riched20.dll"

load_riched20()
{
    # FIXME: this verb used to also install riched32.  Does anyone need that?
    helper_win2ksp4 i386/riched20.dl_
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_TMP"/i386/riched20.dl_
    w_override_dlls native,builtin riched20

    # https://code.google.com/p/winetricks/issues/detail?id=292
    w_call msls31
}

#----------------------------------------------------------------

# Problem - riched20 and riched30 both install riched20.dll!
# We may need a better way to distinguish between installed files.

w_metadata riched30 dlls \
    title="MS RichEdit Control 3.0 (riched20.dll, msls31.dll)" \
    publisher="Microsoft" \
    year="2001" \
    media="download" \
    file1="InstMsiA.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/riched20.dll" \
    installed_file2="$W_SYSTEM32_DLLS_WIN/msls31.dll"

load_riched30()
{
    # http://www.novell.com/documentation/nm1/readmeen_web/readmeen_web.html#Akx3j64
    # claims that Groupwise Messenger's View / Text Size command
    # only works with riched30, and recommends getting it by installing
    # msi 2, which just happens to come with riched30 version of riched20
    # (though not with a corresponding riched32, which might be a problem)
    # http://www.microsoft.com/downloads/details.aspx?displaylang=en&FamilyID=CEBBACD8-C094-4255-B702-DE3BB768148F
    w_download http://download.microsoft.com/download/WindowsInstaller/Install/2.0/W9XMe/EN-US/InstMsiA.exe e739c40d747e7c27aacdb07b50925b1635ee7366
    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/riched30/InstMsiA.exe
    w_try cp -f "$W_TMP"/riched20.dll "$W_SYSTEM32_DLLS"
    w_try cp -f "$W_TMP"/msls31.dll "$W_SYSTEM32_DLLS"
    w_override_dlls native,builtin riched20
}

#----------------------------------------------------------------

w_metadata richtx32 dlls \
    title="MS Rich TextBox Control 6.0" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="richtx32.cab" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/RichTx32.Ocx"

load_richtx32()
{
    w_download http://activex.microsoft.com/controls/vb6/richtx32.cab da404b566df3ad74fe687c39404a36c3e7cadc07
    w_try_cabextract "$W_CACHE"/richtx32/richtx32.cab -d "$W_SYSTEM32_DLLS" -F RichTx32.ocx
    w_try_regsvr RichTx32.ocx
}

#----------------------------------------------------------------

w_metadata sdl dlls \
    title="Simple DirectMedia Layer" \
    publisher="Sam Lantinga" \
    year="2009" \
    media="download" \
    file1="SDL-1.2.14-win32.zip" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/SDL.dll"

load_sdl()
{
    # http://www.libsdl.org/download-1.2.php
    w_download http://www.libsdl.org/release/SDL-1.2.14-win32.zip d22c71d1c2bdf283548187c4b0bd7ef9d0c1fb23
    w_try_unzip "$W_SYSTEM32_DLLS" "$W_CACHE"/sdl/SDL-1.2.14-win32.zip SDL.dll
}

#----------------------------------------------------------------

w_metadata secur32 dlls \
    title="MS Security Support Provider Interface" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="Windows2000-KB959426-x86-ENU.EXE" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/secur32.dll"

load_secur32()
{
    # http://www.microsoft.com/downloads/details.aspx?familyid=c4e408d7-6716-4a12-ad3a-8029667f5c84
    w_download http://download.microsoft.com/download/6/9/5/69501788-B62F-44D8-933F-B6FAA576CA87/Windows2000-KB959426-x86-ENU.EXE bf930a4d2982165a0793465bb255d494ba5b4cf7
    w_try_cabextract "$W_CACHE"/secur32/Windows2000-KB959426-x86-ENU.EXE -d "$W_SYSTEM32_DLLS" -F secur32.dll
    w_override_dlls native,builtin secur32
}

#----------------------------------------------------------------

w_metadata setupapi dlls \
    title="MS Setup API" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="../xpsp3/WindowsXP-KB936929-SP3-x86-ENU.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/setupapi.dll"

load_setupapi()
{
    helper_xpsp3 i386/setupapi.dl_
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_TMP"/i386/setupapi.dl_

    w_override_dlls native,builtin setupapi
}

#----------------------------------------------------------------

w_metadata shockwave dlls \
    title="Shockwave" \
    publisher="Adobe" \
    year="2010" \
    media="download" \
    file1="sw_lic_full_installer.msi" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/Adobe/Shockwave 12/shockwave_Projector_Loader.dcr"

load_shockwave() {
    # Not silent enough, use MSI instead
    #w_download http://fpdownload.macromedia.com/get/shockwave/default/english/win95nt/latest/Shockwave_Installer_Full.exe 840e34e9b067cf247bfa9092665b8966158f38e3
    #w_try "$WINE" "$W_CACHE"/Shockwave_Installer_Full.exe $W_UNATTENDED_SLASH_S
    # old sha1sum: 6a91a9da4b54c3fdc97130a15e1a173117e5f4ff
    # 2009-07-31 sha1sum: 0bb506ef67a268e8d3fb6c7ce556320ee10b9da5
    # 2009-12-13 sha1sum: d35649883bf13cb1a86f5650e1050d15533ac0f4
    # 2010-01-23 sha1sum: 4a837d238c28c5f345d73f105711f20c6d059273
    # 2010-05-15 sha1sum: bdce02afc82233801e84137e78c2c5fe574db253
    # 2010-09-02 sha1sum: fed20eccc29fec2f64162b7265343514d43884bc
    # 2010-11-03 sha1sum: 2ff28665543e80f3bd4ff1933ac05ec9314aaac6
    # 2011-02-03 sha1sum: e71ddc4fa42662208b2f52c1bd34a40e7775ad75
    # 2011-06-13 sha1sum: 7fd6cc61bb20d0bef654a44f4501a5a65b55b0c9
    # 2011-11-10 sha1sum: b55974b471c516f13fb032424247c07390baf380
    # 2012-03-07 sha1sum: 3b10f645ba1a6815fa97924a6bde4eda3177ff68
    # 2012-04-26 sha1sum: 48b1a44b2c12c486916d641f3b4e20abffb3d6e4
    # 2012-08-08 sha1sum: 3c4d531ccf0bb5788f1c197c63e9c0aa89885ee6
    # 2013-06-15 sha1sum: 9c02499deaf567bde7d827493705e5680833d02e
    # 2014-01-22 sha1sum: c8f1b2c137a1373d591f7c1d48db9c6baa961caf
    # 2014-02-26 sha1sum: ae2855b729bfaedc766f3addd8c2b74eac576909
    # 2014-04-15 sha1sum: c2ea56450fb4a5bac66cb7d70e3b522431521787
    # 2014-05-21 sha1sum: d95d1a14ee264235b29e093105bd2baa8b06eb12
    # 2014-11-22 sha1sum: 644d3228654ded798eabe40e7044b96b90e742f6
    # 2015-03-30 sha1sum: 9f2d4d929e7210ae9fb633881127b21586ffd8ce
    # 2015-04-27 sha1sum: 244e6a5c5fa2dd26c136bc5b402f6cad588763d7
    # 2015-08-02 sha1sum: e2efa2eb7db0a6de08905cd61bb3efcf58fda994
    # 2015-11-09 sha1sum: d13420a6fdc4f8d9c45c5ee6767974f0f0054cdc
    # 2015-12-27 sha1sum: 3ac6d85e54dffb2940c89fc10e63363a47ec96d0
    # 2016-02-18 sha1sum: 45147a791e3f71bd67ead1622d9120060dd196e5
    # 2016-03-11 sha1sum: 4f955f42984ae69d2f6078d3a3fe9fadc4a25e34
    
    w_download http://fpdownload.macromedia.com/get/shockwave/default/english/win95nt/latest/sw_lic_full_installer.msi 4f955f42984ae69d2f6078d3a3fe9fadc4a25e34
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" msiexec /i sw_lic_full_installer.msi $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata speechsdk dlls \
    title="MS Speech SDK 5.1" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="SpeechSDK51.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/Microsoft Speech SDK 5.1/Bin/SAPI51SampleApp.exe"

load_speechsdk()
{
    # http://www.microsoft.com/download/en/details.aspx?id=10121
    w_download http://download.microsoft.com/download/B/4/3/B4314928-7B71-4336-9DE7-6FA4CF00B7B3/SpeechSDK51.exe f69efaee8eb47f8c7863693e8b8265a3c12c4f51

    w_try_unzip "$W_TMP" "$W_CACHE"/speechsdk/SpeechSDK51.exe

    # Otherwise it only installs the SDK and not the redistributable:
    w_set_winver win2k

    cd "$W_TMP"
    w_try "$WINE" msiexec /i "Microsoft Speech SDK 5.1.msi" $W_UNATTENDED_SLASH_Q

    w_unset_winver
}

#----------------------------------------------------------------

w_metadata tabctl32 dlls \
    title="Microsoft Tabbed Dialog Control 6.0 (tabctl32.ocx)" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="TABCTL32.CAB" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/tabctl32.ocx"

load_tabctl32()
{
    # http://msdn.microsoft.com/en-us/library/aa240864(VS.60).aspx
    # Nov 2012: tabctl32
    w_download http://activex.microsoft.com/controls/vb6/TABCTL32.CAB beca51d05924a5466ab80eb0f8d0cdf8bc1ac697

    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/tabctl32/${file1}
    w_try cp -f "$W_TMP"/[Tt][Aa][Bb][Cc][Tt][Ll][3][2].[Oo][Cc][Xx] "$W_SYSTEM32_DLLS"
    w_try_regsvr tabctl32.ocx
}

#----------------------------------------------------------------

w_metadata updspapi dlls \
    title="Windows Update Service API" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="../xpsp3/WindowsXP-KB936929-SP3-x86-ENU.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/updspapi.dll"

load_updspapi()
{
    helper_xpsp3 i386/update/updspapi.dll
    w_try cp -f "$W_TMP"/i386/update/updspapi.dll "$W_SYSTEM32_DLLS"

    w_override_dlls native,builtin updspapi
}

#----------------------------------------------------------------

w_metadata usp10 dlls \
    title="Uniscribe 1.325 " \
    publisher="Microsoft" \
    year="2001" \
    media="download" \
    file1="../msi2/InstMsiA.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/usp10.dll"

load_usp10()
{
    # https://en.wikipedia.org/wiki/Uniscribe
    # http://www.microsoft.com/downloads/details.aspx?familyid=cebbacd8-c094-4255-b702-de3bb768148f
    w_download_to msi2 http://download.microsoft.com/download/WindowsInstaller/Install/2.0/W9XMe/EN-US/InstMsiA.exe e739c40d747e7c27aacdb07b50925b1635ee7366
    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/msi2/InstMsiA.exe
    w_try cp -f "$W_TMP"/usp10.dll "$W_SYSTEM32_DLLS"
    w_override_dlls native,builtin usp10
}

#----------------------------------------------------------------

w_metadata vb2run dlls \
    title="MS Visual Basic 2 runtime" \
    publisher="Microsoft" \
    year="1993" \
    media="download" \
    file1="VBRUN200.EXE" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/VBRUN200.DLL"

load_vb2run()
{
    # Not referenced on MS web anymore, but the old Microsoft Software Library FTP still has it.
    # See ftp://ftp.microsoft.com/Softlib/index.txt
    # 2014/05/31: Microsoft FTP is down ftp://$ftp_microsoft_com/Softlib/MSLFILES/VBRUN200.EXE
    # 2015/08/10: chatnfiles is down, conradshome.com is up (and has a LOT of old MS installers archived!)
    w_download http://www.conradshome.com/win31/archive/softlib/vbrun200.exe ac0568b73ee375408778e9b505df995f79ab907e
    w_try_unzip "$W_TMP" "$W_CACHE"/vb2run/VBRUN200.EXE
    w_try cp -f "$W_TMP/VBRUN200.DLL" "$W_SYSTEM32_DLLS"
}

#----------------------------------------------------------------

w_metadata vb3run dlls \
    title="MS Visual Basic 3 runtime" \
    publisher="Microsoft" \
    year="1998" \
    media="download" \
    file1="vb3run.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/Vbrun300.dll"

load_vb3run()
{
    # See http://support.microsoft.com/kb/196285
    w_download http://download.microsoft.com/download/vb30/utility/1/w9xnt4/en-us/vb3run.exe 518fcfefde9bf680695cadd06512efadc5ac2aa7
    w_try_unzip "$W_TMP" "$W_CACHE"/vb3run/vb3run.exe
    w_try cp -f "$W_TMP/Vbrun300.dll" "$W_SYSTEM32_DLLS"
}

#----------------------------------------------------------------

w_metadata vb4run dlls \
    title="MS Visual Basic 4 runtime" \
    publisher="Microsoft" \
    year="1998" \
    media="download" \
    file1="vb4run.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/Vb40032.dll"

load_vb4run()
{
    # See http://support.microsoft.com/kb/196286
    w_download http://download.microsoft.com/download/vb40ent/sample27/1/w9xnt4/en-us/vb4run.exe 83e968063272e97bfffd628a73bf0ff5f8e1023b
    w_try_unzip "$W_TMP" "$W_CACHE"/vb4run/vb4run.exe
    w_try cp -f "$W_TMP/Vb40032.dll" "$W_SYSTEM32_DLLS"
    w_try cp -f "$W_TMP/Vb40016.dll" "$W_SYSTEM32_DLLS"
}

#----------------------------------------------------------------

w_metadata vb5run dlls \
    title="MS Visual Basic 5 runtime" \
    publisher="Microsoft" \
    year="2001" \
    media="download" \
    file1="msvbvm50.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msvbvm50.dll"

load_vb5run()
{
    w_download http://download.microsoft.com/download/vb50pro/utility/1/win98/en-us/msvbvm50.exe 28bfaf09b8ac32cf5ffa81252f3e2fadcb3a8f27
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" msvbvm50.exe $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata vb6run dlls \
    title="MS Visual Basic 6 runtime sp6" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="vbrun60sp6.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/MSVBVM60.DLL"

load_vb6run()
{
    # http://support.microsoft.com/kb/290887
    if test ! -f "$W_CACHE"/vb6run/vbrun60sp6.exe
    then
        w_download http://download.microsoft.com/download/5/a/d/5ad868a0-8ecd-4bb0-a882-fe53eb7ef348/VB6.0-KB290887-X86.exe 73ef177008005675134d2f02c6f580515ab0d842

        w_try "$WINE" "$W_CACHE"/vb6run/VB6.0-KB290887-X86.exe "/T:$W_TMP_WIN" /c $W_UNATTENDED_SLASH_Q
        if test ! -f "$W_TMP"/vbrun60sp6.exe
        then
            w_die vbrun60sp6.exe not found
        fi
        w_try mv "$W_TMP"/vbrun60sp6.exe "$W_CACHE"/vb6run
    fi

    # Delete some fake DLLs to ensure that the installer overwrites them.
    rm -f "$W_SYSTEM32_DLLS"/comcat.dll
    rm -f "$W_SYSTEM32_DLLS"/oleaut32.dll
    rm -f "$W_SYSTEM32_DLLS"/olepro32.dll
    rm -f "$W_SYSTEM32_DLLS"/stdole2.tlb

    cd "$W_CACHE/$W_PACKAGE"
    # Exits with status 43 for some reason?
    "$WINE" vbrun60sp6.exe $W_UNATTENDED_SLASH_Q

    status=$?
    case $status in
    0|43) ;;
    *) w_die $W_PACKAGE installation failed
    esac
}

#----------------------------------------------------------------

winetricks_vcrun6_helper() {
    if test ! -f "$W_CACHE"/vcrun6/vcredist.exe
    then
        w_download_to vcrun6 http://download.microsoft.com/download/vc60pro/Update/2/W9XNT4/EN-US/VC6RedistSetup_deu.exe a8c4dd33e281c166488846a10edf97ff0ce37044

        w_try "$WINE" "$W_CACHE"/vcrun6/vc6redistsetup_deu.exe "/T:$W_TMP_WIN" /c $W_UNATTENDED_SLASH_Q
        if test ! -f "$W_TMP"/vcredist.exe
        then
            w_die vcredist.exe not found
        fi
        mv "$W_TMP"/vcredist.exe "$W_CACHE"/vcrun6
    fi
}

w_metadata vcrun6 dlls \
    title="Visual C++ 6 SP4 libraries (mfc42, msvcp60, msvcirt)" \
    publisher="Microsoft" \
    year="2000" \
    media="download" \
    file1="vc6redistsetup_deu.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/mfc42.dll"

load_vcrun6()
{
    # Load the Visual C++ 6 runtime libraries, including the elusive mfc42u.dll
    winetricks_vcrun6_helper

    # Delete some fake DLLs to avoid vcredist installer warnings
    rm -f "$W_SYSTEM32_DLLS"/comcat.dll
    rm -f "$W_SYSTEM32_DLLS"/msvcrt.dll
    rm -f "$W_SYSTEM32_DLLS"/oleaut32.dll
    rm -f "$W_SYSTEM32_DLLS"/olepro32.dll
    rm -f "$W_SYSTEM32_DLLS"/stdole2.tlb
    "$WINE" "$W_CACHE"/vcrun6/vcredist.exe

    status=$?
    case $status in
    0|43) ;;
    *) w_die vcrun6 installation failed
    esac

    # And then some apps need mfc42u.dll, dunno what the right way
    # is to get it, vcredist doesn't seem to install it by default?
    load_mfc42
}

w_metadata mfc42 dlls \
    title="Visual C++ 6 SP4 mfc42 library; part of vcrun6" \
    publisher="Microsoft" \
    year="2000" \
    media="download" \
    file1="../vcrun6/vc6redistsetup_deu.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/mfc42u.dll"

load_mfc42()
{
    winetricks_vcrun6_helper

    w_try_cabextract "$W_CACHE"/vcrun6/vcredist.exe -d "$W_SYSTEM32_DLLS" -F "mfc42*.dll"
}

w_metadata msvcirt dlls \
    title="Visual C++ 6 SP4 msvcirt library; part of vcrun6" \
    publisher="Microsoft" \
    year="2000" \
    media="download" \
    file1="../vcrun6/vc6redistsetup_deu.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msvcirt.dll"

load_msvcirt()
{
    winetricks_vcrun6_helper

    w_try_cabextract "$W_CACHE"/vcrun6/vcredist.exe -d "$W_SYSTEM32_DLLS" -F msvcirt.dll
}

#----------------------------------------------------------------

# FIXME: we don't currently have an install check that can distinguish
# between SP4 and SP6, it would have to check size or version of a file,
# or maybe a registry key.

w_metadata vcrun6sp6 dlls \
    title="Visual C++ 6 SP6 libraries (with fixes in ATL and MFC)" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="Vs6sp6.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/mfc42.dll"

load_vcrun6sp6()
{
    w_download http://download.microsoft.com/download/1/9/f/19fe4660-5792-4683-99e0-8d48c22eed74/Vs6sp6.exe 2292437a8967349261c810ae8b456592eeb76620

    # No EULA is presented when passing command-line extraction arguments,
    # so we'll simplify extraction with cabextract.
    w_try_cabextract "$W_CACHE"/vcrun6sp6/Vs6sp6.exe -d "$W_TMP" -F vcredist.exe
    cd "$W_TMP"

    # Delete some fake DLLs to avoid vcredist installer warnings
    w_try rm -f "$W_SYSTEM32_DLLS"/comcat.dll
    w_try rm -f "$W_SYSTEM32_DLLS"/msvcrt.dll
    w_try rm -f "$W_SYSTEM32_DLLS"/oleaut32.dll
    w_try rm -f "$W_SYSTEM32_DLLS"/olepro32.dll
    w_try rm -f "$W_SYSTEM32_DLLS"/stdole2.tlb
    # vcredist still exits with status 43.  Anyone know why?
    "$WINE" vcredist.exe

    status=$?
    case $status in
    0|43) ;;
    *) w_die $W_PACKAGE installation failed
    esac

    # And then some apps need mfc42u.dll, dont know what right way
    # is to get it, vcredist doesn't install it by default?
    w_try_cabextract vcredist.exe -d "$W_SYSTEM32_DLLS" -F mfc42u.dll
    # Should the mfc42 verb install this one instead?
}

#----------------------------------------------------------------

w_metadata vcrun2003 dlls \
    title="Visual C++ 2003 libraries (mfc71,msvcp71,msvcr71)" \
    publisher="Microsoft" \
    year="2003" \
    media="download" \
    file1="BZEditW32_1.6.5.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/msvcp71.dll"

load_vcrun2003()
{
    # Load the Visual C++ 2003 runtime libraries
    # Sadly, I know of no Microsoft URL for these
    echo "Installing BZFlag (which comes with the Visual C++ 2003 runtimes)"
    # winetricks-test can't handle ${file1} in url since it does a raw parsing :/
    w_download https://sourceforge.net/projects/bzflag/files/bzedit%20win32/1.6.5/BZEditW32_1.6.5.exe bdd1b32c4202fd77e6513fd507c8236888b09121
    w_try "$WINE" "$W_CACHE"/vcrun2003/${file1} $W_UNATTENDED_SLASH_S
    w_try cp "$W_PROGRAMS_X86_UNIX/BZEdit1.6.5"/m*71* "$W_SYSTEM32_DLLS"
}

#----------------------------------------------------------------

# Temporary fix for bug 169
# The | symbol in installed_file1 means "or".
# (Adding an installed_file2 would mean 'and'.)
# Perhaps we should test for one if winxp mode, and the other if win7 mode;
# if that becomes important to get right, we'll do something like
# "if installed_file1 is just the single char @, call test_installed_$verb"
# and then define that function here.
w_metadata vcrun2005 dlls \
    title="Visual C++ 2005 libraries (mfc80,msvcp80,msvcr80)" \
    publisher="Microsoft" \
    year="2011" \
    media="download" \
    file1="vcredist_x86.EXE" \
    installed_file1="c:/windows/winsxs/x86_Microsoft.VC80.MFC_1fc8b3b9a1e18e3b_8.0.50727.6195_x-ww_150c9e8b/mfc80.dll|c:/windows/winsxs/x86_microsoft.vc80.mfc_1fc8b3b9a1e18e3b_8.0.50727.6195_none_deadbeef/mfc80.dll"

load_vcrun2005()
{
    # June 2011 security update, see
    # http://www.microsoft.com/technet/security/bulletin/MS11-025.mspx or
    # http://support.microsoft.com/kb/2538242
    w_download http://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.EXE b8fab0bb7f62a24ddfe77b19cd9a1451abd7b847

    cd "$W_CACHE/$W_PACKAGE"
    w_override_dlls native,builtin atl80 msvcm80 msvcp80 msvcr80 vcomp
    w_try "$WINE" $file1 $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata vcrun2008 dlls \
    title="Visual C++ 2008 libraries (mfc90,msvcp90,msvcr90)" \
    publisher="Microsoft" \
    year="2011" \
    media="download" \
    file1="vcredist_x86.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/Common Files/Microsoft Shared/VC/msdia90.dll"

load_vcrun2008()
{
    # June 2011 security update, see
    # http://www.microsoft.com/technet/security/bulletin/MS11-025.mspx or
    # http://support.microsoft.com/kb/2538242
    w_download http://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe 470640aa4bb7db8e69196b5edb0010933569e98d
    w_override_dlls native,builtin atl90 msvcm90 msvcp90 msvcr90 vcomp90
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" $file1 $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata vcrun2010 dlls \
    title="Visual C++ 2010 libraries (mfc100,msvcp100,msvcr100)" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="vcredist_x86.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/mfc100.dll"

load_vcrun2010()
{
    # See http://www.microsoft.com/downloads/details.aspx?FamilyID=a7b7a05e-6de6-4d3a-a423-37bf0912db84
    w_download http://download.microsoft.com/download/5/B/C/5BC5DBB3-652D-4DCE-B14A-475AB85EEF6E/vcredist_x86.exe 372d9c1670343d3fb252209ba210d4dc4d67d358

    w_override_dlls native,builtin msvcp100 msvcr100 vcomp100 atl100
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" vcredist_x86.exe $W_UNATTENDED_SLASH_Q

    case "$W_ARCH" in
    win64)
        # Also install the 64-bit version
        # http://www.microsoft.com/en-us/download/details.aspx?id=13523
        w_download http://download.microsoft.com/download/A/8/0/A80747C3-41BD-45DF-B505-E9710D2744E0/vcredist_x64.exe 027d0c2749ec5eb21b031f46aee14c905206f482
        if w_workaround_wine_bug 30713 "Manually extracting the 64-bit dlls"
        then
            w_try_cabextract --directory="$W_TMP" vcredist_x64.exe -F '*.cab'
            w_try_cabextract --directory="$W_TMP" "$W_TMP"/vc_red.cab
            cp "$W_TMP"/F_CENTRAL_mfc100_x64 "$W_SYSTEM64_DLLS"/mfc100.dll
            cp "$W_TMP"/F_CENTRAL_mfc100u_x64 "$W_SYSTEM64_DLLS"/mfc100u.dll
            cp "$W_TMP"/F_CENTRAL_msvcr100_x64 "$W_SYSTEM64_DLLS"/msvcr100.dll
            cp "$W_TMP"/F_CENTRAL_msvcp100_x64 "$W_SYSTEM64_DLLS"/msvcp100.dll
            cp "$W_TMP"/F_CENTRAL_vcomp100_x64 "$W_SYSTEM64_DLLS"/vcomp100.dll
            cp "$W_TMP"/F_CENTRAL_atl100_x64 "$W_SYSTEM64_DLLS"/atl100.dll
        else
            w_try "$WINE" vcredist_x64.exe $W_UNATTENDED_SLASH_Q
        fi
        ;;
    esac
}

#----------------------------------------------------------------

w_metadata vcrun2012 dlls \
    title="Visual C++ 2012 libraries (atl110,mfc110,mfc110u,msvcp110,msvcr110,vcomp110)" \
    publisher="Microsoft" \
    year="2012" \
    media="download" \
    file1="vcredist_x86.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/mfc110.dll"

load_vcrun2012()
{
    # http://www.microsoft.com/download/details.aspx?id=30679
    w_download http://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe 96b377a27ac5445328cbaae210fc4f0aaa750d3f

    w_override_dlls native,builtin atl110 msvcp110 msvcr110 vcomp110
    cd "$W_CACHE"/"$W_PACKAGE"
    w_try "$WINE" vcredist_x86.exe $W_UNATTENDED_SLASH_Q

    case "$W_ARCH" in
    win64)
        # Also install the 64-bit version
        # 2015/10/19: 1a5d93dddbc431ab27b1da711cd3370891542797
        w_download http://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe 1a5d93dddbc431ab27b1da711cd3370891542797
        if w_workaround_wine_bug 30713 "Manually extracting the 64-bit dlls"
        then
            rm -f "$W_TMP"/*  # Avoid permission error
            w_try_cabextract --directory="$W_TMP" vcredist_x64.exe
            w_try_cabextract --directory="$W_TMP" "$W_TMP/a2"
            w_try_cabextract --directory="$W_TMP" "$W_TMP/a3"
            cp "$W_TMP"/F_CENTRAL_atl110_x64 "$W_SYSTEM64_DLLS"/atl110.dll
            cp "$W_TMP"/F_CENTRAL_mfc110_x64 "$W_SYSTEM64_DLLS"/mfc110.dll
            cp "$W_TMP"/F_CENTRAL_mfc110u_x64 "$W_SYSTEM64_DLLS"/mfc110u.dll
            cp "$W_TMP"/F_CENTRAL_msvcp110_x64 "$W_SYSTEM64_DLLS"/msvcp110.dll
            cp "$W_TMP"/F_CENTRAL_msvcr110_x64 "$W_SYSTEM64_DLLS"/msvcr110.dll
            cp "$W_TMP"/F_CENTRAL_vcomp110_x64 "$W_SYSTEM64_DLLS"/vcomp110.dll
        else
            w_try "$WINE" vcredist_x64.exe $W_UNATTENDED_SLASH_Q
        fi
        ;;
    esac
}

#----------------------------------------------------------------

w_metadata vcrun2013 dlls \
    title="Visual C++ 2013 libraries (mfc120,mfc120u,msvcp120,msvcr120,vcomp120)" \
    publisher="Microsoft" \
    year="2013" \
    media="download" \
    file1="vcredist_x86.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/mfc120.dll"

load_vcrun2013()
{
    # http://www.microsoft.com/en-us/download/details.aspx?id=40784
    # 2014/07/26: 18f81495bc5e6b293c69c28b0ac088a96debbab2
    # 2015/01/14: df7f0a73bfa077e483e51bfb97f5e2eceedfb6a3
    w_download http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe df7f0a73bfa077e483e51bfb97f5e2eceedfb6a3

    w_override_dlls native,builtin atl120 msvcp120 msvcr120 vcomp120
    cd "$W_CACHE"/"$W_PACKAGE"
    w_try "$WINE" vcredist_x86.exe $W_UNATTENDED_SLASH_Q

    case "$W_ARCH" in
    win64)
        # Also install the 64-bit version
        # 2015/10/19: 8bf41ba9eef02d30635a10433817dbb6886da5a2
        w_download http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe 8bf41ba9eef02d30635a10433817dbb6886da5a2
        if w_workaround_wine_bug 30713 "Manually extracting the 64-bit dlls"
        then
            rm -f "$W_TMP"/*  # Avoid permission error
            w_try_cabextract --directory="$W_TMP" vcredist_x64.exe
            w_try_cabextract --directory="$W_TMP" "$W_TMP/a2"
            w_try_cabextract --directory="$W_TMP" "$W_TMP/a3"
            cp "$W_TMP"/F_CENTRAL_mfc120_x64 "$W_SYSTEM64_DLLS"/mfc120.dll
            cp "$W_TMP"/F_CENTRAL_mfc120u_x64 "$W_SYSTEM64_DLLS"/mfc120u.dll
            cp "$W_TMP"/F_CENTRAL_msvcp120_x64 "$W_SYSTEM64_DLLS"/msvcp120.dll
            cp "$W_TMP"/F_CENTRAL_msvcr120_x64 "$W_SYSTEM64_DLLS"/msvcr120.dll
            cp "$W_TMP"/F_CENTRAL_vcomp120_x64 "$W_SYSTEM64_DLLS"/vcomp120.dll
        else
            w_try "$WINE" vcredist_x64.exe $W_UNATTENDED_SLASH_Q
        fi
        ;;
    esac
}

#----------------------------------------------------------------

w_metadata vcrun2015 dlls \
    title="Visual C++ 2015 libraries (concrt140.dll,mfc140.dll,mfc140u.dll,mfcm140.dll,mfcm140u.dll,msvcp140.dll,vcamp140.dll,vccorlib140.dll,vcomp140.dll,vcruntime140.dll)" \
    publisher="Microsoft" \
    year="2015" \
    media="download" \
    file1="vc_redist.x86.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/mfc140.dll"

load_vcrun2015()
{
    # https://www.microsoft.com/en-us/download/details.aspx?id=48145
    # 2015/10/12: bfb74e498c44d3a103ca3aa2831763fb417134d1
    w_download https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x86.exe bfb74e498c44d3a103ca3aa2831763fb417134d1

    if w_workaround_wine_bug 37781
    then
        w_warn "This may fail in non-XP mode, see https://bugs.winehq.org/show_bug.cgi?id=37781"
    fi

    w_override_dlls native,builtin api-ms-win-crt-conio-l1-1-0 api-ms-win-crt-heap-l1-1-0 api-ms-win-crt-locale-l1-1-0 api-ms-win-crt-math-l1-1-0.dll api-ms-win-crt-runtime-l1-1-0 api-ms-win-crt-stdio-l1-1-0 atl140 msvcp140 msvcr140 ucrtbase vcomp140 vcruntime140

    cd "$W_CACHE"/"$W_PACKAGE"
    w_try "$WINE" vc_redist.x86.exe $W_UNATTENDED_SLASH_Q

    case "$W_ARCH" in
    win64)
        # Also install the 64-bit version
        # 2015/10/12: 3155cb0f146b927fcc30647c1a904cd162548c8c
        w_download https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe 3155cb0f146b927fcc30647c1a904cd162548c8c
        if w_workaround_wine_bug 30713 "Manually extracting the 64-bit dlls"
        then
            rm -f "$W_TMP"/*  # Avoid permission error
            w_try_cabextract --directory="$W_TMP" vc_redist.x64.exe
            w_try_cabextract --directory="$W_TMP" "$W_TMP/a10"
            w_try_cabextract --directory="$W_TMP" "$W_TMP/a11"
            cp "$W_TMP"/concrt140.dll "$W_SYSTEM64_DLLS"/concrt140.dll
            cp "$W_TMP"/mfc140.dll "$W_SYSTEM64_DLLS"/mfc140.dll
            cp "$W_TMP"/mfc140u.dll "$W_SYSTEM64_DLLS"/mfc140u.dll
            cp "$W_TMP"/mfcm140.dll "$W_SYSTEM64_DLLS"/mfcm140.dll
            cp "$W_TMP"/mfcm140u.dll "$W_SYSTEM64_DLLS"/mfcm140u.dll
            cp "$W_TMP"/msvcp140.dll "$W_SYSTEM64_DLLS"/msvcp140.dll
            cp "$W_TMP"/vcamp140.dll "$W_SYSTEM64_DLLS"/vcamp140.dll
            cp "$W_TMP"/vccorlib140.dll "$W_SYSTEM64_DLLS"/vccorlib140.dll
            cp "$W_TMP"/vcomp140.dll "$W_SYSTEM64_DLLS"/vcomp140.dll
            cp "$W_TMP"/vcruntime140.dll "$W_SYSTEM64_DLLS"/vcruntime140.dll

            cp "$W_TMP"/api_ms_win_crt_conio_l1_1_0.dll "$W_SYSTEM64_DLLS"/api-ms-win-crt-conio-l1-1-0.dll
            cp "$W_TMP"/api_ms_win_crt_heap_l1_1_0.dll "$W_SYSTEM64_DLLS"/api-ms-win-crt-heap-l1-1-0.dll
            cp "$W_TMP"/api_ms_win_crt_locale_l1_1_0.dll "$W_SYSTEM64_DLLS"/api-ms-win-crt-locale-l1-1-0.dll
            cp "$W_TMP"/api_ms_win_crt_math_l1_1_0.dll "$W_SYSTEM64_DLLS"/api-ms-win-crt-math-l1-1-0.dll
            cp "$W_TMP"/api_ms_win_crt_runtime_l1_1_0.dll "$W_SYSTEM64_DLLS"/api-ms-win-crt-runtime-l1-1-0.dll
            cp "$W_TMP"/api_ms_win_crt_stdio_l1_1_0.dll "$W_SYSTEM64_DLLS"/api-ms-win-crt-stdio-l1-1-0.dll
            cp "$W_TMP"/ucrtbase.dll "$W_SYSTEM64_DLLS"/ucrtbase.dll
        else
            w_try "$WINE" vc_redist.x64.exe $W_UNATTENDED_SLASH_Q
        fi
        ;;
    esac
}

#----------------------------------------------------------------

w_metadata vjrun20 dlls \
    title="MS Visual J# 2.0 SE libraries (requires dotnet20)" \
    publisher="Microsoft" \
    year="2007" \
    media="download" \
    conflicts="dotnet11 dotnet20sp1 dotnet20sp2" \
    file1="vjredist.exe" \
    installed_file1="c:/windows/Microsoft.NET/Framework/VJSharp/VJSharpSxS10.dll"

load_vjrun20()
{
    if [ $W_ARCH = win64 ]
    then
        w_warn "vjrun20 depends on dotnet20, which doesn't work on 64-bit Wine yet. Skipping."
        return
    fi

    w_call dotnet20

    # See http://www.microsoft.com/downloads/details.aspx?FamilyId=E9D87F37-2ADC-4C32-95B3-B5E3A21BAB2C
    w_download http://download.microsoft.com/download/9/2/3/92338cd0-759f-4815-8981-24b437be74ef/vjredist.exe 80a098e36b90d159da915aebfbfbacf35f302bd8
    cd "$W_CACHE"/"$W_PACKAGE"
    w_try "$WINE" vjredist.exe ${W_OPT_UNATTENDED:+ /q /C:"install $W_UNATTENDED_SLASH_QNT"}
}

#----------------------------------------------------------------

# FIXME: two exe's, one for win64, one for win32..

w_metadata windowscodecs dlls \
    title="MS Windows Imaging Component" \
    publisher="Microsoft" \
    year="2006" \
    media="download" \
    file1="wic_x86_enu.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/WindowsCodecs.dll"

load_windowscodecs()
{
    # Separate 32/64-bit installers:
    if [ "$W_ARCH" = "win32" ] ; then
        # https://www.microsoft.com/en-us/download/details.aspx?id=32
        w_download http://download.microsoft.com/download/f/f/1/ff178bb1-da91-48ed-89e5-478a99387d4f/wic_x86_enu.exe 53c18652ac2f8a51303deb48a1b7abbdb1db427f
        EXE="wic_x86_enu.exe"
    else
        # https://www.microsoft.com/en-us/download/details.aspx?id=1385
        w_download https://download.microsoft.com/download/6/4/5/645FED5F-A6E7-44D9-9D10-FE83348796B0/wic_x64_enu.exe 4bdbf76a7bc96453306c893b4a7b2b8ae6127f67
        EXE="wic_x64_enu.exe"
   fi

    # Avoid a file existence check.
    w_try rm -f "$W_SYSTEM32_DLLS"/windowscodecs.dll "$W_SYSTEM32_DLLS"/windowscodecsext.dll "$W_SYSTEM32_DLLS"/photometadatahandler.dll

    if [ "$W_ARCH" = "win64" ]
    then
         w_try rm -f "$W_SYSTEM64_DLLS"/windowscodecs.dll "$W_SYSTEM64_DLLS"/windowscodecsext.dll "$W_SYSTEM64_DLLS"/photometadatahandler.dll
    fi

    # AF says in AppDB entry for .NET 3.0 that windowscodecs has to be native only
    w_override_dlls native windowscodecs windowscodecsext

    # Always run the WIC installer in passive mode.
    # See http://bugs.winehq.org/show_bug.cgi?id=16876 and
    # http://bugs.winehq.org/show_bug.cgi?id=23232
    cd "$W_CACHE/$W_PACKAGE"

    if test -x /usr/bin/taskset && w_workaround_wine_bug 32859 "Working around possibly broken libX11"
    then
        TASKSET="taskset -c 0"
    else
        TASKSET=""
    fi
    w_try $TASKSET "$WINE" "$EXE" /passive
}

#----------------------------------------------------------------

w_metadata winhttp dlls \
    title="MS Windows HTTP Services" \
    publisher="Microsoft" \
    year="2005" \
    media="download" \
    file1="../win2ksp4/W2KSP4_EN.EXE" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/winhttp.dll"

load_winhttp()
{
    helper_win2ksp4 i386/new/winhttp.dl_
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_TMP"/i386/new/winhttp.dl_
    w_override_dlls native,builtin winhttp
}

#----------------------------------------------------------------

w_metadata wininet dlls \
    title="MS Windows Internet API" \
    publisher="Microsoft" \
    year="2008" \
    media="download" \
    file1="../win2ksp4/W2KSP4_EN.EXE" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/wininet.dll"

load_wininet()
{
    helper_win2ksp4 i386/wininet.dl_
    w_try_cabextract --directory="$W_SYSTEM32_DLLS" "$W_TMP"/i386/wininet.dl_
    w_override_dlls native,builtin wininet
}

#----------------------------------------------------------------

w_metadata wmi dlls \
    title="Windows Management Instrumentation (aka WBEM) Core 1.5" \
    publisher="Microsoft" \
    year="2000" \
    media="download" \
    file1="wmi9x.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/wbem/wbemcore.dll"

load_wmi()
{
    if test $W_ARCH = win64
    then
        w_die "Installer doesn't support 64-bit architecture."
    fi

    # WMI for NT4.0 need validation: http://www.microsoft.com/downloads/en/details.aspx?FamilyID=c174cfb1-ef67-471d-9277-4c2b1014a31e
    # See also http://www.microsoft.com/downloads/en/details.aspx?FamilyId=98A4C5BA-337B-4E92-8C18-A63847760EA5
    w_download http://download.microsoft.com/download/platformsdk/wmi9x/1.5/W9X/EN-US/wmi9x.exe 62752e9c1b879688c26f205eebf07d3783906c3e

    w_set_winver win98
    w_override_dlls native,builtin wbemprox wmiutils
    # Note: there is a crash in the background towards the end, doesn't seem to hurt; see http://bugs.winehq.org/show_bug.cgi?id=7920
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" wmi9x.exe $W_UNATTENDED_SLASH_S
    w_unset_winver
}

#----------------------------------------------------------------

w_metadata wmv9vcm dlls \
    title="MS Windows Media Video 9 Video Compression Manager" \
    publisher="Microsoft" \
    year="2013" \
    media="download" \
    file1="WindowsServer2003-WindowsMedia-KB2845142-x86-ENU.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/wmv9vcm.dll"

load_wmv9vcm()
{
    # https://www.microsoft.com/en-us/download/details.aspx?id=39486
    # See also https://www.microsoft.com/en-us/download/details.aspx?id=6191
    w_download https://download.microsoft.com/download/2/8/D/28DA9C3E-6DA2-456F-BD33-1F937EB6E0FF/WindowsServer2003-WindowsMedia-KB2845142-x86-ENU.exe 0ace94c09bfab15410db3a15ffa42370891266de
    w_try_cabextract --directory="$W_TMP" "$W_CACHE/$W_PACKAGE/$file1"
    w_try cp -f "$W_TMP"/wm64/wmv9vcm.dll "$W_SYSTEM32_DLLS"

    # Register codec:
    cat > "$W_TMP"/tmp.reg <<_EOF_
REGEDIT4
[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Drivers32]
"vidc.WMV3"="wmv9vcm.dll"

_EOF_
    w_try_regedit "$W_TMP_WIN"\\tmp.reg
}

#----------------------------------------------------------------

w_metadata wsh56js dlls \
    title="MS Windows Script Host 5.6, JScript only, no CScript" \
    publisher="Microsoft" \
    year="2006" \
    media="download" \
    file1="Windows2000-KB917344-56-x86-enu.exe" \
    installed_file1="c:/windows/inf/jscren.inf"

load_wsh56js()
{
    # This installs JScript 5.6 (but not VBScript)
    # See also http://www.microsoft.com/downloads/details.aspx?FamilyID=16dd21a1-c4ee-4eca-8b80-7bd1dfefb4f8&DisplayLang=en
    w_download http://download.microsoft.com/download/b/c/3/bc3a0c36-fada-497d-a3de-8b0139766f3b/Windows2000-KB917344-56-x86-enu.exe add5f74c5bd4da6cfae47f8306de213ec6ed52c8

    cd "$W_CACHE/$W_PACKAGE"
    w_override_dlls native,builtin jscript
    # setupapi looks at the versions in new and original jscript.dll, and Wine's original is newer than wsh56js's, so we have to nuke the original
    w_try rm "$W_SYSTEM32_DLLS/jscript.dll"
    w_try "$WINE" Windows2000-KB917344-56-x86-enu.exe $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata wsh56vb dlls \
    title="MS Windows Script Host 5.6, VBScript only, no CScript" \
    publisher="Microsoft" \
    year="2007" \
    media="download" \
    file1="vbs56men.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/vbscript.dll"

load_wsh56vb()
{
    # This installs VBScript 5.6 (but not JScript)
    # See also http://www.microsoft.com/downloads/details.aspx?familyid=4F728263-83A3-464B-BCC0-54E63714BC75
    w_download http://download.microsoft.com/download/IE60/Patch/Q318089/W9XNT4Me/EN-US/vbs56men.exe 48f14a93db33caff271da0c93f334971f9d7cb22

    cd "$W_CACHE/$W_PACKAGE"
    w_override_dlls native,builtin vbscript
    # setupapi looks at the versions in new and original vbscript.dll, and Wine's original is newer than wsh56vb's, so we have to nuke the original
    w_try rm "$W_SYSTEM32_DLLS/vbscript.dll"
    w_try "$WINE" vbs56men.exe $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata wsh57 dlls \
    title="MS Windows Script Host 5.7" \
    publisher="Microsoft" \
    year="2007" \
    media="download" \
    file1="scripten.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/scrrun.dll"

load_wsh57()
{
    # See also http://www.microsoft.com/downloads/details.aspx?FamilyID=47809025-D896-482E-A0D6-524E7E844D81&displaylang=en
    w_download http://download.microsoft.com/download/4/4/d/44de8a9e-630d-4c10-9f17-b9b34d3f6417/scripten.exe b15c6a834b7029e2dfed22127cf905b06857e6f5

    w_try_cabextract -d "$W_SYSTEM32_DLLS" "$W_CACHE"/wsh57/scripten.exe

    # Wine doesn't provide the other dll's (yet?)
    w_override_dlls native,builtin jscript scrrun vbscript cscript.exe wscript.exe
    w_try_regsvr dispex.dll jscript.dll scrobj.dll scrrun.dll vbscript.dll wshcon.dll wshext.dll
}

#----------------------------------------------------------------

w_metadata xact dlls \
    title="MS XACT Engine" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/xactengine2_0.dll"

load_xact()
{
    helper_directx_dl

    # Extract xactengine?_?.dll, X3DAudio?_?.dll, xaudio?_?.dll, xapofx?_?.dll
    w_try_cabextract -d "$W_TMP" -L -F '*_xact_*x86*' "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_TMP" -L -F '*_x3daudio_*x86*' "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_TMP" -L -F '*_xaudio_*x86*' "$W_CACHE"/directx9/$DIRECTX_NAME
    for x in "$W_TMP"/*.cab
    do
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'xactengine*.dll' "$x"
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'xaudio*.dll' "$x"
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'x3daudio*.dll' "$x"
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'xapofx*.dll' "$x"
    done
    if test "$W_ARCH" = "win64"
    then
        w_try_cabextract -d "$W_TMP" -L -F '*_xact_*x64*' "$W_CACHE"/directx9/$DIRECTX_NAME
        w_try_cabextract -d "$W_TMP" -L -F '*_x3daudio_*x64*' "$W_CACHE"/directx9/$DIRECTX_NAME
        w_try_cabextract -d "$W_TMP" -L -F '*_xaudio_*x64*' "$W_CACHE"/directx9/$DIRECTX_NAME
        for x in "$W_TMP"/*x64.cab
        do
          w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F 'xactengine*.dll' "$x"
          w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F 'xaudio*.dll' "$x"
          w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F 'x3daudio*.dll' "$x"
          w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F 'xapofx*.dll' "$x"
        done
    fi

    # Register xactengine?_?.dll
    for x in "$W_SYSTEM32_DLLS"/xactengine*
    do
      w_try_regsvr `basename "$x"`
    done

    # and xaudio?_?.dll, but not xaudio2_8 (unsupported)
    for x in 0 1 2 3 4 5 6 7
    do
      w_try_regsvr `basename "$W_SYSTEM32_DLLS/xaudio2_${x}"`
    done
}

#----------------------------------------------------------------

w_metadata xact_jun2010 dlls \
    title="MS XACT Engine" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_Jun2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/xactengine2_0.dll"

load_xact_jun2010()
{
    helper_directx_Jun2010

    # Extract xactengine?_?.dll, X3DAudio?_?.dll, xaudio?_?.dll, xapofx?_?.dll
    w_try_cabextract -d "$W_TMP" -L -F '*_xact_*x86*' "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_TMP" -L -F '*_x3daudio_*x86*' "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_TMP" -L -F '*_xaudio_*x86*' "$W_CACHE"/directx9/$DIRECTX_NAME
    for x in "$W_TMP"/*.cab
    do
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'xactengine*.dll' "$x"
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'xaudio*.dll' "$x"
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'x3daudio*.dll' "$x"
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'xapofx*.dll' "$x"
    done
    if test "$W_ARCH" = "win64"
    then
        w_try_cabextract -d "$W_TMP" -L -F '*_xact_*x64*' "$W_CACHE"/directx9/$DIRECTX_NAME
        w_try_cabextract -d "$W_TMP" -L -F '*_x3daudio_*x64*' "$W_CACHE"/directx9/$DIRECTX_NAME
        w_try_cabextract -d "$W_TMP" -L -F '*_xaudio_*x64*' "$W_CACHE"/directx9/$DIRECTX_NAME
        for x in "$W_TMP"/*x64.cab
        do
          w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F 'xactengine*.dll' "$x"
          w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F 'xaudio*.dll' "$x"
          w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F 'x3daudio*.dll' "$x"
          w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F 'xapofx*.dll' "$x"
        done
    fi

    # Register xactengine?_?.dll
    for x in "$W_SYSTEM32_DLLS"/xactengine*
    do
      w_try_regsvr `basename "$x"`
    done

    # and xaudio?_?.dll, but not xaudio2_8 (unsupported)
    for x in 0 1 2 3 4 5 6 7
    do
      w_try_regsvr `basename "$W_SYSTEM32_DLLS/xaudio2_${x}"`
    done
}

#----------------------------------------------------------------

w_metadata xinput dlls \
    title="Microsoft XInput (Xbox controller support)" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/xinput1_1.dll"

load_xinput()
{
    helper_directx_dl

    w_try_cabextract -d "$W_TMP" -L -F '*_xinput_*x86*' "$W_CACHE"/directx9/$DIRECTX_NAME
    for x in "$W_TMP"/*.cab
    do
      w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F 'xinput*.dll' "$x"
    done
    if test "$W_ARCH" = "win64"
    then
        w_try_cabextract -d "$W_TMP" -L -F '*_xinput_*x64*' "$W_CACHE"/directx9/$DIRECTX_NAME
        for x in "$W_TMP"/*x64.cab
        do
            w_try_cabextract -d "$W_SYSTEM64_DLLS" -L -F 'xinput*.dll' "$x"
        done
    fi
    w_override_dlls native xinput1_1
    w_override_dlls native xinput1_2
    w_override_dlls native xinput1_3
    w_override_dlls native xinput9_1_0
}

#----------------------------------------------------------------

# FIXME: extend metadata to allow file1_en, file1_fr, etc.
w_metadata xmllite dlls \
    title="MS xmllite dll" \
    publisher="Microsoft" \
    year="2006" \
    media="download" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/xmllite.dll"

load_xmllite()
{
    case $LANG in
    en*) w_download http://download.microsoft.com/download/f/9/6/f964059a-3747-4ed8-9326-ba1e639031b1/WindowsXP-KB915865-v11-x86-ENU.exe 226d246a1c64e693791de5c727509002d089b0d5 ;;
    fr*) w_download http://download.microsoft.com/download/4/1/d/41de58a0-6715-4d3e-99e7-ff0c11283d1b/WindowsXP-KB915865-v11-x86-FRA.exe abb70b6a96be7dce453b00877739e90c6f3efba0 ;;
    de*) w_download http://download.microsoft.com/download/9/b/6/9b67efdb-cce3-4247-a2e0-386673859a1b/WindowsXP-KB915865-v11-x86-DEU.exe a03a325815acf9d624db58ab94a140a5586e64c8 ;;
    ja*) w_download http://download.microsoft.com/download/f/5/c/f5cf73b7-4dc4-4042-815d-29d2fd24ae6f/WindowsXP-KB915865-v11-x86-JPN.exe eaf443d04d9b13cb86f927f8a7fe372268386395 ;;
    *) w_die "Sorry, xmllite install not yet implemented for language $LANG" ;;
    esac

    # Doesn't install in newer versions:
    w_set_winver winxp

    cd "$W_CACHE/$W_PACKAGE"
    w_override_dlls native xmllite
    case $LANG in
    en*) w_try "$WINE" WindowsXP-KB915865-v11-x86-ENU.exe $W_UNATTENDED_SLASH_Q ;;
    fr*) w_try "$WINE" WindowsXP-KB915865-v11-x86-FRA.exe $W_UNATTENDED_SLASH_Q ;;
    de*) w_try "$WINE" WindowsXP-KB915865-v11-x86-DEU.exe $W_UNATTENDED_SLASH_Q ;;
    ja*) w_try "$WINE" WindowsXP-KB915865-v11-x86-JPN.exe $W_UNATTENDED_SLASH_Q ;;
    esac

    w_unset_winver
}

#----------------------------------------------------------------

w_metadata xna31 dlls \
    title="MS XNA Framework Redistributable 3.1" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="xnafx31_redist.msi" \
    installed_file1="C:/windows/assembly/GAC_32/Microsoft.Xna.Framework.Game/3.1.0.0__6d5c3888ef60e27d/Microsoft.Xna.Framework.Game.dll"

load_xna31()
{
    w_call dotnet20sp2
    w_download http://download.microsoft.com/download/5/9/1/5912526C-B950-4662-99B6-119A83E60E5C/xnafx31_redist.msi bdd33b677c9576a63ff2a6f65e12c0563cc116e6
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" msiexec $W_UNATTENDED_SLASH_QUIET /i $file1
}

#----------------------------------------------------------------

w_metadata xna40 dlls \
    title="MS XNA Framework Redistributable 4.0" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="xnafx40_redist.msi" \
    installed_file1="$W_PROGRAMS_X86_WIN/Common Files/Microsoft Shared/XNA/Framework/v4.0/XnaNative.dll"

load_xna40()
{
    if w_workaround_bug 30718
    then
        w_warn "$W_PACKAGE may not install properly in Wine yet"
    fi

    # See https://bugs.winehq.org/show_bug.cgi?id=30718#c8
    export COMPlus_OnlyUseLatestCLR=1
    w_call dotnet40

    # http://www.microsoft.com/en-us/download/details.aspx?id=20914
    w_download http://download.microsoft.com/download/A/C/2/AC2C903B-E6E8-42C2-9FD7-BEBAC362A930/xnafx40_redist.msi 49efdc29f65fc8263c196338552c7009fc96c5de
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" msiexec $W_UNATTENDED_SLASH_QUIET /i $file1
}

#----------------------------------------------------------------

w_metadata xvid dlls \
    title="Xvid Video Codec" \
    publisher="xvid.org" \
    year="2009" \
    media="download" \
    file1="Xvid-1.3.2-20110601.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/Xvid/xvid.ico"

load_xvid()
{
    w_call vcrun6
    w_download http://www.koepi.info/Xvid-1.3.2-20110601.exe 0a11498a96f75ad019c4c7d06161504140337dc0
    cd "$W_CACHE"/"$W_PACKAGE"
    w_try "$WINE" $file1 ${W_OPT_UNATTENDED:+ --mode unattended --decode_divx 1 --decode_3ivx 1 --decode_other 1}
}

#----------------------------------------------------------------
# Fonts
#----------------------------------------------------------------

w_metadata baekmuk fonts \
    title="Baekmuk Korean fonts" \
    publisher="Wooderart Inc. / kldp.net" \
    year="1999" \
    media="download" \
    file1="fonts-baekmuk_2.2.orig.tar.gz" \
    installed_file1="$W_FONTSDIR_WIN/batang.ttf"

load_baekmuk()
{
    # See http://kldp.net/projects/baekmuk for project page
    # Need to download from Debian as the project page has unique captcha tokens per visitor
    w_download http://http.debian.net/debian/pool/main/f/fonts-baekmuk/fonts-baekmuk_2.2.orig.tar.gz afdee34f700007de6ea87b43c92a88b7385ba65b

    cd "$W_TMP"
    tar zxvf "$W_CACHE/$W_PACKAGE/$file1" baekmuk-ttf-2.2/ttf
    w_try mv baekmuk-ttf-2.2/ttf/*.ttf "$W_FONTSDIR_UNIX"
    w_register_font batang.ttf "Baekmuk Batang"
    w_register_font gulim.ttf "Baekmuk Gulim"
    w_register_font dotum.ttf "Baekmuk Dotum"
    w_register_font hline.ttf "Baekmuk Headline"
}

#----------------------------------------------------------------

w_metadata cjkfonts fonts \
    title="All Chinese, Japanese, Korean fonts and aliases" \
    publisher="various" \
    date="1999-2010" \
    media="download"

load_cjkfonts()
{
    w_call fakechinese
    w_call fakejapanese
    w_call fakekorean
    w_call unifont
}

#----------------------------------------------------------------

w_metadata cambria fonts \
    title="MS Cambria font" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="PowerPointViewer.exe" \
    installed_file1="$W_FONTSDIR_WIN/cambria.ttc"

load_cambria()
{
    # http://www.microsoft.com/en-us/download/details.aspx?id=13
    w_download_to consolas http://download.microsoft.com/download/E/6/7/E675FFFC-2A6D-4AB0-B3EB-27C9F8C8F696/PowerPointViewer.exe ab48a8ebac88219c84f293c6c1e81f1a0f420da6
    w_try_cabextract -d "$W_TMP" -L -F ppviewer.cab "$W_CACHE"/consolas/PowerPointViewer.exe
    w_try_cabextract -d "$W_FONTSDIR_UNIX" -L -F 'CAMBRIA*.TT*' "$W_TMP"/ppviewer.cab
    w_register_font cambria.ttc "Cambria"
    w_register_font cambriab.ttf "Cambria Bold"
    w_register_font cambriai.ttf "Cambria Italic"
    w_register_font cambriaz.ttf "Cambria Bold Italic"
}

#----------------------------------------------------------------

w_metadata constantia fonts \
    title="MS Constantia font" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="PowerPointViewer.exe" \
    installed_file1="$W_FONTSDIR_WIN/constan.ttf"

load_constantia()
{
    # http://www.microsoft.com/en-us/download/details.aspx?id=13
    w_download_to consolas http://download.microsoft.com/download/E/6/7/E675FFFC-2A6D-4AB0-B3EB-27C9F8C8F696/PowerPointViewer.exe ab48a8ebac88219c84f293c6c1e81f1a0f420da6
    w_try_cabextract -d "$W_TMP" -L -F ppviewer.cab "$W_CACHE"/consolas/PowerPointViewer.exe
    w_try_cabextract -d "$W_FONTSDIR_UNIX" -L -F 'CONSTAN*.TTF' "$W_TMP"/ppviewer.cab
    w_register_font constan.ttf "Constantia"
    w_register_font constanb.ttf "Constantia Bold"
    w_register_font constani.ttf "Constantia Italic"
    w_register_font constanz.ttf "Constantia Bold Italic"
}

#----------------------------------------------------------------

w_metadata consolas fonts \
    title="MS Consolas console font" \
    publisher="Microsoft" \
    year="2011" \
    media="download" \
    file1="PowerPointViewer.exe" \
    installed_file1="$W_FONTSDIR_WIN/consola.ttf"

load_consolas()
{
    # http://www.microsoft.com/en-us/download/details.aspx?id=13
    w_download http://download.microsoft.com/download/E/6/7/E675FFFC-2A6D-4AB0-B3EB-27C9F8C8F696/PowerPointViewer.exe ab48a8ebac88219c84f293c6c1e81f1a0f420da6
    w_try_cabextract -d "$W_TMP" -L -F ppviewer.cab "$W_CACHE"/consolas/PowerPointViewer.exe
    w_try_cabextract -d "$W_FONTSDIR_UNIX" -L -F 'CONSOL*.TTF' "$W_TMP"/ppviewer.cab
    w_register_font consola.ttf "Consoleas"
    w_register_font consolab.ttf "Consoleas Bold"
    w_register_font consolai.ttf "Consoleas Italic"
    w_register_font consolaz.ttf "Consoleas Bold Italic"
}

#----------------------------------------------------------------

w_metadata corefonts fonts \
    title="MS Arial, Courier, Times fonts" \
    publisher="Microsoft" \
    year="2008" \
    media="download" \
    file1="arial32.exe" \
    installed_file1="$W_FONTSDIR_WIN/Arial.TTF"

load_corefonts()
{
    # FIXME: why is this commented out? Should be removed or enabled.
    #w_download ftp://ftp.fi.debian.org/gentoo/distfiles/andale32.exe c4db8cbe42c566d12468f5fdad38c43721844c69
    w_download ftp://ftp.fi.debian.org/gentoo/distfiles/arial32.exe 6d75f8436f39ab2da5c31ce651b7443b4ad2916e
    w_download ftp://ftp.fi.debian.org/gentoo/distfiles/arialb32.exe d45cdab84b7f4c1efd6d1b369f50ed0390e3d344
    w_download ftp://ftp.fi.debian.org/gentoo/distfiles/comic32.exe 2371d0327683dcc5ec1684fe7c275a8de1ef9a51
    w_download ftp://ftp.fi.debian.org/gentoo/distfiles/courie32.exe 06a745023c034f88b4135f5e294fece1a3c1b057
    w_download ftp://ftp.fi.debian.org/gentoo/distfiles/georgi32.exe 90e4070cb356f1d811acb943080bf97e419a8f1e
    w_download ftp://ftp.fi.debian.org/gentoo/distfiles/impact32.exe 86b34d650cfbbe5d3512d49d2545f7509a55aad2
    w_download ftp://ftp.fi.debian.org/gentoo/distfiles/times32.exe 20b79e65cdef4e2d7195f84da202499e3aa83060
    w_download ftp://ftp.fi.debian.org/gentoo/distfiles/trebuc32.exe 50aab0988423efcc9cf21fac7d64d534d6d0a34a
    w_download ftp://ftp.fi.debian.org/gentoo/distfiles/verdan32.exe f5b93cedf500edc67502f116578123618c64a42a
    w_download ftp://ftp.fi.debian.org/gentoo/distfiles/webdin32.exe 2fb4a42c53e50bc70707a7b3c57baf62ba58398f

    # Natively installed versions of these fonts will cause the installers
    # to exit silently. Because there are apps out there that depend on the
    # files being present in the Windows font directory we use cabextract
    # to obtain the files and register the fonts by hand.

    # Andale needs a FontSubstitutes entry
    # w_try_cabextract --directory="$W_TMP" "$W_CACHE"/corefonts/andale32.exe

    # Display EULA
    test x"$W_UNATTENDED_SLASH_Q" = x"" || w_try "$WINE" "$W_CACHE"/corefonts/arial32.exe $W_UNATTENDED_SLASH_Q

    w_try_cabextract -q --directory="$W_TMP" "$W_CACHE"/corefonts/arial32.exe
    w_try cp -f "$W_TMP"/Arial*.TTF "$W_FONTSDIR_UNIX"
    w_register_font Arial.TTF "Arial"
    w_register_font Arialbd.TTF "Arial Bold"
    w_register_font Arialbi.TTF "Arial Bold Italic"
    w_register_font Ariali.TTF "Arial Italic"

    w_try_cabextract -q --directory="$W_TMP" "$W_CACHE"/corefonts/arialb32.exe
    w_try cp -f "$W_TMP"/AriBlk.TTF "$W_FONTSDIR_UNIX"
    w_register_font AriBlk.TTF "Arial Black"

    w_try_cabextract -q --directory="$W_TMP" "$W_CACHE"/corefonts/comic32.exe
    w_try cp -f "$W_TMP"/Comic*.TTF "$W_FONTSDIR_UNIX"
    w_register_font Comic.TTF "Comic Sans MS"
    w_register_font Comicbd.TTF "Comic Sans MS Bold"

    w_try_cabextract -q --directory="$W_TMP" "$W_CACHE"/corefonts/courie32.exe
    w_try cp -f "$W_TMP"/cour*.ttf "$W_FONTSDIR_UNIX"
    w_register_font Cour.TTF "Courier New"
    w_register_font CourBD.TTF "Courier New Bold"
    w_register_font CourBI.TTF "Courier New Bold Italic"
    w_register_font Couri.TTF "Courier New Italic"

    w_try_cabextract -q --directory="$W_TMP" "$W_CACHE"/corefonts/georgi32.exe
    w_try cp -f "$W_TMP"/Georgia*.TTF "$W_FONTSDIR_UNIX"
    w_register_font Georgia.TTF "Georgia"
    w_register_font Georgiab.TTF "Georgia Bold"
    w_register_font Georgiaz.TTF "Georgia Bold Italic"
    w_register_font Georgiai.TTF "Georgia Italic"

    w_try_cabextract -q --directory="$W_TMP" "$W_CACHE"/corefonts/impact32.exe
    w_try cp -f "$W_TMP"/Impact.TTF "$W_FONTSDIR_UNIX"
    w_register_font Impact.TTF "Impact"

    w_try_cabextract -q --directory="$W_TMP" "$W_CACHE"/corefonts/times32.exe
    w_try cp -f "$W_TMP"/Times*.TTF "$W_FONTSDIR_UNIX"
    w_register_font Times.TTF "Times New Roman"
    w_register_font Timesbd.TTF "Times New Roman Bold"
    w_register_font Timesbi.TTF "Times New Roman Bold Italic"
    w_register_font Timesi.TTF "Times New Roman Italic"

    w_try_cabextract -q --directory="$W_TMP" "$W_CACHE"/corefonts/trebuc32.exe
    w_try cp -f "$W_TMP"/[tT]rebuc*.ttf "$W_FONTSDIR_UNIX"
    w_register_font Trebuc.TTF "Trebucet MS"
    w_register_font Trebucbd.TTF "Trebucet MS Bold"
    w_register_font Trebucbi.TTF "Trebucet MS Bold Italic"
    w_register_font Trebucit.TTF "Trebucet MS Italic"

    w_try_cabextract -q --directory="$W_TMP" "$W_CACHE"/corefonts/verdan32.exe
    w_try cp -f "$W_TMP"/Verdana*.TTF "$W_FONTSDIR_UNIX"
    w_register_font Verdana.TTF "Verdana"
    w_register_font Verdanab.TTF "Verdana Bold"
    w_register_font Verdanaz.TTF "Verdana Bold Italic"
    w_register_font Verdanai.TTF "Verdana Italic"

    w_try_cabextract -q --directory="$W_TMP" "$W_CACHE"/corefonts/webdin32.exe
    w_try cp -f "$W_TMP"/Webdings.TTF "$W_FONTSDIR_UNIX"
    w_register_font Webdings.TTF "Webdings"
}

#----------------------------------------------------------------

w_metadata droid fonts \
    title="Droid fonts" \
    publisher="Ascender Corporation" \
    year="2009" \
    media="download" \
    file1="DroidSans-Bold.ttf" \
    installed_file1="$W_FONTSDIR_WIN/DroidSans-Bold.ttf"

do_droid() {
    w_download ${DROID_URL}$1'?raw=true'   $3  $1
    w_try cp -f "$W_CACHE"/droid/$1 "$W_FONTSDIR_UNIX"
    w_register_font $1 "$2"
}

load_droid()
{
    # See https://en.wikipedia.org/wiki/Droid_(font)
    # Old URL was http://android.git.kernel.org/?p=platform/frameworks/base.git;a=blob_plain;f=data/fonts/'
    # Then it was https://github.com/android/platform_frameworks_base/blob/master/data/fonts/
    # but the fonts are no longer in master. Using an older commit instead:
    DROID_URL='https://github.com/android/platform_frameworks_base/blob/feef9887e8f8eb6f64fc1b4552c02efb5755cdc1/data/fonts/'

    do_droid DroidSans-Bold.ttf        "Droid Sans Bold"         560e4bcafdebaf29645fbf92633a2ae0d2f9801f
    do_droid DroidSansFallback.ttf     "Droid Sans Fallback"     c5e4f11e2f1d0b84e5f268a7ebfd28b54dc6bcdc
    do_droid DroidSansJapanese.ttf     "Droid Sans Japanese"     b3a248c11692aa88a30eb25df425b8910fe05dc5
    do_droid DroidSansMono.ttf         "Droid Sans Mono"         133fb6cf26ea073b456fb557b94ce8c46143b117
    do_droid DroidSans.ttf             "Droid Sans"              62f2841f61e4be66a0303cd1567ed2d300b4e31c
    do_droid DroidSerif-BoldItalic.ttf "Droid Serif Bold Italic" 41ce5fef1bd0164caed6958885d7285c841c95f1
    do_droid DroidSerif-Bold.ttf       "Droid Serif Bold"        2775e9b8e96a3e9593acb5cf6923abb2e6008187
    do_droid DroidSerif-Italic.ttf     "Droid Serif Italic"      e91cc6c1ae9a6699683bcee024551cb58d1be790
    do_droid DroidSerif-Regular.ttf    "Droid Serif"             a689ce25a4063cf501c12d616f832f2235b5b93b
}

#----------------------------------------------------------------

w_metadata eufonts fonts \
    title="Updated fonts for Romanian and Bulgarian" \
    publisher="Microsoft" \
    year="2008" \
    media="download" \
    file1="EUupdate.EXE" \
    installed_file1="$W_FONTSDIR_WIN/trebucbd.ttf"

load_eufonts()
{
    # https://www.microsoft.com/downloads/details.aspx?FamilyID=0ec6f335-c3de-44c5-a13d-a1e7cea5ddea&displaylang=en
    w_download http://download.microsoft.com/download/a/1/8/a180e21e-9c2b-4b54-9c32-bf7fd7429970/EUupdate.EXE 9b076c40cb63aa0d8512aa8e610ba11d3466e441
    w_try_cabextract -q --directory="$W_TMP" "$W_CACHE"/eufonts/EUupdate.EXE
    w_try cp -f "$W_TMP"/*.ttf "$W_FONTSDIR_UNIX"

    w_register_font ArialBI.ttf "Arial Bold Italic"
    w_register_font ArialI.ttf "Arial Italic"
    w_register_font Arial.ttf "Arial"
    w_register_font TimesBd.ttf "Times New Roman Bold"
    w_register_font TimesBI.ttf "Times New Roman Bold Italic"
    w_register_font TimesI.ttf "Times New Roman Italic"
    w_register_font Times.ttf "Times New Roman"
    w_register_font trebucbd.ttf "Trebuchet Bold"
    w_register_font trebucbi.ttf "Trebuchet Bold Italic"
    w_register_font trebucit.ttf "Trebuchet Italic"
    w_register_font trebuc.ttf "Trebuchet"
    w_register_font Verdanab.ttf "Verdana Bold"
    w_register_font Verdanai.ttf "Verdana Italian"
    w_register_font Verdana.ttf "Verdana"
    w_register_font Verdanaz.ttf "Verdana Bold Italic"
}

#----------------------------------------------------------------

w_metadata fakechinese fonts \
    title="Creates aliases for Chinese fonts using WenQuanYi fonts" \
    publisher="wenq.org" \
    year="2009"

load_fakechinese()
{
    w_call wenquanyi
    # Loads Wenquanyi fonts and sets aliases for Microsoft Chinese fonts
    # Reference : http://en.wikipedia.org/wiki/List_of_Microsoft_Windows_fonts

    w_register_font_replacement "Microsoft JhengHei" "WenQuanYi Micro Hei"
    w_register_font_replacement "Microsoft YaHei" "WenQuanYi Micro Hei"
    w_register_font_replacement "SimHei" "WenQuanYi Micro Hei"
    w_register_font_replacement "DFKai-SB" "WenQuanYi Micro Hei"
    w_register_font_replacement "FangSong" "WenQuanYi Micro Hei"
    w_register_font_replacement "KaiTi" "WenQuanYi Micro Hei"
    w_register_font_replacement "PMingLiU" "WenQuanYi Micro Hei"
    w_register_font_replacement "MingLiU" "WenQuanYi Micro Hei"
    w_register_font_replacement "NSimSun" "WenQuanYi Micro Hei"
    w_register_font_replacement "SimKai" "WenQuanYi Micro Hei"
    w_register_font_replacement "SimSun" "WenQuanYi Micro Hei"
}

#----------------------------------------------------------------

w_metadata fakejapanese fonts \
    title="Creates aliases for Japanese fonts using Takao fonts" \
    publisher="Jun Kobayashi" \
    year="2010"

load_fakejapanese()
{
    w_call takao
    # Loads Takao fonts and sets aliases for MS Gothic, MS UI Gothic, and MS PGothic, mainly for Japanese language support
    # Aliases to set:
    # MS Gothic --> TakaoGothic
    # MS UI Gothic --> TakaoGothic
    # MS PGothic --> TakaoPGothic
    # MS Mincho --> TakaoMincho
    # MS PMincho --> TakaoPMincho
    # These aliases were taken from what was listed in Ubuntu's fontconfig definitions.

    w_register_font_replacement "MS Gothic" "TakaoGothic"
    w_register_font_replacement "MS UI Gothic" "TakaoGothic"
    w_register_font_replacement "MS PGothic" "TakaoPGothic"
    w_register_font_replacement "MS Mincho" "TakaoMincho"
    w_register_font_replacement "MS PMincho" "TakaoPMincho"
}

#----------------------------------------------------------------

w_metadata fakejapanese_ipamona fonts \
    title="Creates aliases for Japanese fonts using IPAMona fonts" \
    publisher="Jun Kobayashi" \
    year="2008"

load_fakejapanese_ipamona()
{
    w_call ipamona

    # Aliases to set:
    # MS UI Gothic --> IPAMonaUIGothic
    # MS Gothic (ＭＳ ゴシック) --> IPAMonaGothic
    # MS PGothic (ＭＳ Ｐゴシック) --> IPAMonaPGothic
    # MS Mincho (ＭＳ 明朝) --> IPAMonaMincho
    # MS PMincho (ＭＳ Ｐ明朝) --> IPAMonaPMincho

    jpname_msgothic="$(echo "ＭＳ ゴシック" | iconv -f utf8 -t cp932)"
    jpname_mspgothic="$(echo "ＭＳ Ｐゴシック" | iconv -f utf8 -t cp932)"
    jpname_msmincho="$(echo "ＭＳ 明朝" | iconv -f utf8 -t cp932)"
    jpname_mspmincho="$(echo "ＭＳ Ｐ明朝" | iconv -f utf8 -t cp932)"

    w_register_font_replacement "MS UI Gothic" "IPAMonaUIGothic"
    w_register_font_replacement "MS Gothic" "IPAMonaGothic"
    w_register_font_replacement "MS PGothic" "IPAMonaPGothic"
    w_register_font_replacement "MS Mincho" "IPAMonaMincho"
    w_register_font_replacement "MS PMincho" "IPAMonaPMincho"
    w_register_font_replacement "$jpname_msgothic" "IPAMonaGothic"
    w_register_font_replacement "$jpname_mspgothic" "IPAMonaPGothic"
    w_register_font_replacement "$jpname_msmincho" "IPAMonaMincho"
    w_register_font_replacement "$jpname_mspmincho" "IPAMonaPMincho"
}

#----------------------------------------------------------------

w_metadata fakekorean fonts \
    title="Creates aliases for Korean fonts using Baekmuk fonts" \
    publisher="Wooderart Inc. / kldp.net" \
    year="1999"

load_fakekorean()
{
    w_call baekmuk
    # Loads Baekmuk fonts and sets as an alias for Gulim, Dotum, and Batang for Korean language support
    # Aliases to set:
    # Gulim --> Baekmuk Gulim
    # GulimChe --> Baekmuk Gulim
    # Batang --> Baekmuk Batang
    # BatangChe --> Baekmuk Batang
    # Dotum --> Baekmuk Dotum
    # DotumChe --> Baekmuk Dotum

    w_register_font_replacement "Gulim" "Baekmuk Gulim"
    w_register_font_replacement "GulimChe" "Baekmuk Gulim"
    w_register_font_replacement "Batang" "Baekmuk Batang"
    w_register_font_replacement "BatangChe" "Baekmuk Batang"
    w_register_font_replacement "Dotum" "Baekmuk Dotum"
    w_register_font_replacement "DotumChe" "Baekmuk Dotum"
}

#----------------------------------------------------------------

w_metadata fontfix settings \
    title="Check for broken fonts"

load_fontfix()
{
    # Some versions of ukai.ttf and uming.ttf crash .NET and Picasa
    # See http://bugs.winehq.org/show_bug.cgi?id=7098#c9
    # Very unlikely to still be around, so downgrade to fatal warning
    if test -f /usr/share/fonts/truetype/arphic/ukai.ttf
    then
        w_get_sha1sum /usr/share/fonts/truetype/arphic/ukai.ttf
        if [ "$_W_gotsum"x = "96e1121f89953e5169d3e2e7811569148f573985"x ]
        then
            w_die "Your installed ukai.ttf is known to be broken. Upgrade your ttf-arphic font package!"
        fi
    fi

    if test -f /usr/share/fonts/truetype/arphic/uming.ttf
    then
        w_get_sha1sum /usr/share/fonts/truetype/arphic/uming.ttf
        if [ "$_W_gotsum"x = "2a4f4a69e343c21c24d044b2cb19fd4f0decc82c"x ]
        then
            w_die "Your installed uming.ttf is known to be broken. Upgrade your ttf-uming font package!"
        fi
    fi

    # Focht says Samyak is bad news, and font substitution isn't a good workaround.
    # I've seen psdkwin7 setup crash because of this; the symptom was a messagebox saying
    # SDKSetup encountered an error: The type initializer for 'Microsoft.WizardFramework.WizardSettings' threw an exception
    # and WINEDEBUG=+relay,+seh shows an exception very quickly after
    # Call KERNEL32.CreateFileW(0c83b36c L"Z:\\USR\\SHARE\\FONTS\\TRUETYPE\\TTF-ORIYA-FONTS\\SAMYAK-ORIYA.TTF",80000000,00000001,00000000,00000003,00000080,00000000) ret=70d44091
    if xlsfonts 2>/dev/null | egrep -i "samyak.*oriya"
    then
        w_die "Please uninstall the Samyak/Oriya font, e.g. 'sudo dpkg -r ttf-oriya-fonts', then log out and log in again.  That font causes strange crashes in .net programs."
    fi
}

#----------------------------------------------------------------

w_metadata ipamona fonts \
    title="IPAMona Japanese fonts" \
    publisher="Jun Kobayashi" \
    year="2008" \
    media="download" \
    file1="opfc-ModuleHP-1.1.1_withIPAMonaFonts-1.0.8.tar.gz" \
    installed_file1="$W_FONTSDIR_WIN/ipag-mona.ttf" \
    homepage="http://www.geocities.jp/ipa_mona/"

load_ipamona()
{
    w_download http://www.geocities.jp/ipa_mona/$file1 57dd13ab58c0005d3ee2932539e4987ab0242bc7

    cd "$W_TMP"

    gunzip -dc "$W_CACHE/$W_PACKAGE/$file1" | tar -xf -
    w_try mv *IPAMonaFonts*/fonts/*.ttf "$W_FONTSDIR_UNIX"

    w_register_font ipagui-mona.ttf "IPAMonaUIGothic"
    w_register_font ipag-mona.ttf "IPAMonaGothic"
    w_register_font ipagp-mona.ttf "IPAMonaPGothic"
    w_register_font ipam-mona.ttf "IPAMonaMincho"
    w_register_font ipamp-mona.ttf "IPAMonaPMincho"
}

#----------------------------------------------------------------

w_metadata liberation fonts \
    title="Red Hat Liberation fonts (Sans, Serif, Mono)" \
    publisher="Red Hat" \
    year="2008" \
    media="download" \
    file1="liberation-fonts-1.04.tar.gz" \
    installed_file1="$W_FONTSDIR_WIN/LiberationMono-BoldItalic.ttf"

load_liberation()
{
    # http://www.redhat.com/promo/fonts/
    case `uname -s` in
    SunOS|Solaris)
      echo "If you get 'ERROR: Certificate verification error for fedorahosted.org: unable to get local issuer certificate':"
      echo "Then you need to add Verisign root certificates to your local keystore."
      echo "OpenSolaris users, see: http://www.linuxtopia.org/online_books/opensolaris_2008/SYSADV1/html/swmgrpatchtasks-14.html"
      echo "Or edit winetricks's download function, and add '--no-check-certificate' to the command."
      ;;
    esac

    w_download https://fedorahosted.org/releases/l/i/liberation-fonts/liberation-fonts-1.04.tar.gz 097882c92e3260742a3dc3bf033792120d8635a3
    cd "$W_TMP"
    gunzip -dc "$W_CACHE"/liberation/liberation-fonts-1.04.tar.gz | tar -xf -
    mv liberation-fonts-1.04/*.ttf "$W_FONTSDIR_UNIX"

    w_register_font LiberationMono-BoldItalic.ttf "LiberationMono-BoldItalic"
    w_register_font LiberationMono-Bold.ttf "LiberationMono-Bold"
    w_register_font LiberationMono-Italic.ttf "LiberationMono-Italic"
    w_register_font LiberationMono-Regular.ttf "LiberationMono-Regular"
    w_register_font LiberationSans-BoldItalic.ttf "LiberationSans-BoldItalic"
    w_register_font LiberationSans-Bold.ttf "LiberationSans-Bold"
    w_register_font LiberationSans-Italic.ttf "LiberationSans-Italic"
    w_register_font LiberationSans-Regular.ttf "LiberationSans-Regular"
    w_register_font LiberationSerif-BoldItalic.ttf "LiberationSerif-BoldItalic"
    w_register_font LiberationSerif-Bold.ttf "LiberationSerif-Bold"
    w_register_font LiberationSerif-Italic.ttf "LiberationSerif-Italic"
    w_register_font LiberationSerif-Regular.ttf "LiberationSerif-Regular"
}

#----------------------------------------------------------------

w_metadata lucida fonts \
    title="MS Lucida Console font" \
    publisher="Microsoft" \
    year="1998" \
    media="download" \
    file1="eurofixi.exe" \
    installed_file1="$W_FONTSDIR_WIN/lucon.ttf"

load_lucida()
{
    w_download ftp://ftp.fu-berlin.de/pc/security/ms-patches/winnt/usa/NT40TSE/hotfixes-postSP3/Euro-fix/eurofixi.exe 64c47ad92265f6f10b0fd909a703d4fd1b05b2d5
    w_try_cabextract -d "$W_FONTSDIR_UNIX" -L -F 'lucon.ttf' "$W_CACHE"/lucida/eurofixi.exe
    w_register_font lucon.ttf "Lucida Console"
}

#----------------------------------------------------------------

w_metadata opensymbol fonts \
    title="OpenSymbol fonts (replacement for Wingdings)" \
    publisher="OpenOffice.org" \
    year="2014" \
    media="download" \
    file1="fonts-opensymbol_102.6+LibO4.3.3-2+deb8u3_all.deb" \
    installed_file1="$W_FONTSDIR_WIN/opens___.ttf"

load_opensymbol()
{
    # The OpenSymbol fonts are a replacement for the Windows Wingdings font from OpenOffice.org.
    # Need to w_download Debian since I can't find a standalone download from OpenOffice
    # Note: The source download package on debian is for _all_ of OpenOffice, which is 266 MB.
    w_download http://security.debian.org/debian-security/pool/updates/main/libr/libreoffice/fonts-opensymbol_102.6+LibO4.3.3-2+deb8u3_all.deb d3e2dd921c6694d24865600e40eceaf2a635d1c6

    cd "$W_TMP"
    w_try_ar "$W_CACHE/$W_PACKAGE/$file1" data.tar.xz
    w_try tar Jvxf "$W_TMP/data.tar.xz" ./usr/share/fonts/truetype/openoffice/opens___.ttf
    w_try mv "$W_TMP/usr/share/fonts/truetype/openoffice/opens___.ttf" "$W_FONTSDIR_UNIX"
    w_register_font opens___.ttf "OpenSymbol"
}

#----------------------------------------------------------------

w_metadata tahoma fonts \
    title="MS Tahoma font (not part of corefonts)" \
    publisher="Microsoft" \
    year="2007" \
    media="download" \
    file1="tahoma32.exe" \
    installed_file1="$W_FONTSDIR_WIN/tahoma.ttf"

load_tahoma()
{
    # The tahoma and tahomabd fonts are needed by e.g. Steam

    w_download http://download.microsoft.com/download/office97pro/fonts/1/w95/en-us/tahoma32.exe 888ce7b7ab5fd41f9802f3a65fd0622eb651a068
    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/tahoma/tahoma32.exe
    w_try cp -f "$W_TMP"/Tahoma.TTF "$W_FONTSDIR_UNIX"/tahoma.ttf
    w_try cp -f "$W_TMP"/Tahomabd.TTF "$W_FONTSDIR_UNIX"/tahomabd.ttf

    # FIXME:  Wine seems to nuke the registry entries for Tahoma.  Why?  Font Xplorer always lists it as 'not installed'.
    w_register_font tahoma.ttf "Tahoma"
    w_register_font tahomabd.ttf "Tahoma Bold"

    # ? does some app assume it can overwrite these, or is this a leftover from before we had install checks?
    chmod +w "$W_FONTSDIR_UNIX"/tahoma*.ttf
}

#----------------------------------------------------------------

w_metadata takao fonts \
    title="Takao Japanese fonts" \
    publisher="Jun Kobayashi" \
    year="2010" \
    media="download" \
    file1="takao-fonts-ttf-003.02.01.zip" \
    installed_file1="$W_FONTSDIR_WIN/TakaoGothic.ttf"

load_takao()
{
    # The Takao font provides Japanese glyphs.  May also be needed with fakejapanese function above.
    # See http://launchpad.net/takao-fonts for project page
    w_download http://launchpad.net/takao-fonts/trunk/003.02.01/+download/takao-fonts-ttf-003.02.01.zip 4f636d5c7c1bc16b96ea723adb16838cfb6df059
    cp -f "$W_CACHE"/takao/takao-fonts-ttf-003.02.01.zip "$W_TMP"
    w_try_unzip "$W_TMP" "$W_TMP"/takao-fonts-ttf-003.02.01.zip
    w_try cp -f "$W_TMP"/takao-fonts-ttf-003.02.01/*.ttf "$W_FONTSDIR_UNIX"

    w_register_font TakaoGothic.ttf "TakaoGothic"
    w_register_font TakaoPGothic.ttf "TakaoPGothic"
    w_register_font TakaoMincho.ttf "TakaoMincho"
    w_register_font TakaoPMincho.ttf "TakaoPMincho"
    w_register_font TakaoExGothic.ttf "TakaoExGothic"
    w_register_font TakaoExMincho.ttf "TakaoExMincho"
}

#----------------------------------------------------------------

w_metadata uff fonts \
    title="Ubuntu Font Family" \
    publisher="Ubuntu" \
    year="2010" \
    media="download" \
    file1="ubuntu-font-family-0.70.1.zip" \
    installed_file1="$W_FONTSDIR_WIN/Ubuntu-R.ttf" \
    homepage="https://launchpad.net/ubuntu-font-family"

load_uff()
{
    w_download http://font.ubuntu.com/download/ubuntu-font-family-0.70.1.zip efbab0d5d8cb5cff091307d2360dcb1bfe1ae6e1
    cd "$W_TMP"
    w_try_unzip . "$W_CACHE"/uff/ubuntu-font-family-0.70.1.zip
    mv ubuntu-font-family-0.70.1/*.ttf "$W_FONTSDIR_UNIX"

    w_register_font Ubuntu-R.ttf "Ubuntu"
    w_register_font Ubuntu-I.ttf "Ubuntu Italic"
    w_register_font Ubuntu-B.ttf "Ubuntu Bold"
    w_register_font Ubuntu-BI.ttf "Ubuntu Bold Italic"
}

#----------------------------------------------------------------

w_metadata wenquanyi fonts \
    title="WenQuanYi CJK font" \
    publisher="wenq.org" \
    year="2009" \
    media="download" \
    file1="wqy-microhei-0.2.0-beta.tar.gz" \
    installed_file1="$W_FONTSDIR_WIN/wqy-microhei.ttc"

load_wenquanyi()
{
    # See http://wenq.org/enindex.cgi
    # Donate at http://wenq.org/enindex.cgi?Download(en)#MicroHei_Beta if you want to help support free CJK font development
    w_download $WINETRICKS_SOURCEFORGE/wqy/wqy-microhei-0.2.0-beta.tar.gz 28023041b22b6368bcfae076de68109b81e77976
    cd "$W_TMP/"
    gunzip -dc "$W_CACHE/wenquanyi/wqy-microhei-0.2.0-beta.tar.gz" | tar -xf -
    w_try mv wqy-microhei/wqy-microhei.ttc "$W_FONTSDIR_UNIX"
    w_register_font wqy-microhei.ttc "WenQuanYi Micro Hei"
}

#----------------------------------------------------------------

w_metadata unifont fonts \
    title="Unifont alternative to Arial Unicode MS" \
    publisher="Roman Czyborra / GNU" \
    year="2008" \
    media="download" \
    file1="unifont-5.1.20080907.zip" \
    installed_file1="$W_FONTSDIR_WIN/unifont.ttf"

load_unifont()
{
    # The GNU Unifont provides glyphs for just about everything in common language.  It is intended for multilingual usage.
    # See http://unifoundry.com/unifont.html for project page
    w_download http://unifoundry.com/unifont-5.1.20080907.zip bb8a3960dc0a96aa305de28312ea8a0ab64123d2
    cp -f "$W_CACHE"/unifont/unifont-5.1.20080907.zip "$W_TMP"
    w_try_unzip "$W_TMP" "$W_TMP"/unifont-5.1.20080907.zip
    w_try cp -f "$W_TMP"/unifont-5.1.20080907.ttf "$W_FONTSDIR_UNIX/unifont.ttf"

    w_register_font unifont.ttf "Unifont"
    w_register_font_replacement "Arial Unicode MS" "Unifont"
}

#----------------------------------------------------------------

w_metadata allfonts fonts \
    title="All fonts" \
    publisher="various" \
    year="1998-2010" \
    media="download"

load_allfonts()
{
    # This verb uses reflection, should probably do it portably instead, but that would require keeping it up to date
    for file in "$WINETRICKS_METADATA"/fonts/*.vars
    do
        cmd=`basename $file .vars`
        case $cmd in
        allfonts|cjkfonts) ;;
        *) w_call $cmd;;
        esac
    done
}

#----------------------------------------------------------------
# Apps
#----------------------------------------------------------------

w_metadata 3m_library apps \
    title="3M Cloud Library" \
    publisher="3M Company" \
    year="2015" \
    media="download" \
    file1="3M-TM-Cloud-Library-PC-App-LIVE-Installer-1.51.735677.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/3M(TM) Cloud Library PC App/3MCloudLibrary.exe"
    homepage="http://www.3m.com/us/library/eBook/index.html"

load_3m_library()
{
    w_download http://www.3m.com/us/library/eBook/docs/3M-TM-Cloud-Library-PC-App-LIVE-Installer-1.51.735677.exe 810dc5f6b74ab7b34893288ee44ef7dc563a4ee7
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" 3M-TM-Cloud-Library-PC-App-LIVE-Installer-1.51.735677.exe $W_UNATTENDED_SLASH_S
}

#----------------------------------------------------------------

w_metadata 7zip apps \
    title="7-Zip 16.02" \
    publisher="Igor Pavlov" \
    year="2016" \
    media="download" \
    file1="7z1602.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/7-Zip/7zFM.exe"

load_7zip()
{
    w_download http://www.7-zip.org/a/7z1602.exe a86f0726019ca84d1de1b036033d888d4538b2a9
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" "${file1}" $W_UNATTENDED_SLASH_S
}

#----------------------------------------------------------------

w_metadata abiword apps \
    title="AbiWord 2.8.6" \
    publisher="AbiSource" \
    year="2010" \
    media="download" \
    file1="abiword-setup-2.8.6.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/AbiWord/bin/AbiWord.exe"

load_abiword()
{
    w_download http://www.abisource.com/downloads/abiword/2.8.6/Windows/abiword-setup-2.8.6.exe a91acd3f60e842d23556032d34f1600602768318
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" abiword-setup-2.8.6.exe $W_UNATTENDED_SLASH_S
}

#----------------------------------------------------------------

w_metadata adobe_diged apps \
    title="Adobe Digital Editions 1.7" \
    publisher="Adobe" \
    year="2011" \
    media="download" \
    file1="setup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Adobe/Adobe Digital Editions/digitaleditions.exe" \
    homepage="http://www.adobe.com/products/digitaleditions/"

load_adobe_diged()
{
    w_download http://kb2.adobe.com/cps/403/kb403051/attachments/setup.exe 4c79685408fa6ca12ef8bb0e0eaa4a846e21f915
    # NSIS installer
    w_try "$WINE" "$W_CACHE"/$W_PACKAGE/setup.exe ${W_OPT_UNATTENDED:+ /S}
}

#----------------------------------------------------------------

w_metadata adobe_diged4 apps \
    title="Adobe Digital Editions 4.5" \
    publisher="Adobe" \
    year="2015" \
    media="download" \
    file1="ADE_4.5_Installer.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Adobe/Adobe Digital Editions 4.5/DigitalEditions.exe" \
    homepage="http://www.adobe.com/products/digitaleditions/"

load_adobe_diged4()
{
    w_download http://download.adobe.com/pub/adobe/digitaleditions/ADE_4.5_Installer.exe

    if w_workaround_wine_bug 32323
    then
        w_call corefonts
    fi
    if [ ! -x "`which winbindd 2>/dev/null`" ]
    then
        w_warn "Adobe Digital Editions 4.5 requires winbind (part of Samba) to be installed, but winbind was not detected."
    fi

    w_call dotnet40

    #w_call win7
    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, ${file1} ${W_OPT_UNATTENDED:+ /S}
        winwait, Installing Adobe Digital Editions
        ControlClick, Button1 ; Don't install Norton Internet Security
        ControlClick, Static19 ; Next
    "
}

#----------------------------------------------------------------

w_metadata audible apps \
    title="Audible.com Manager / Player" \
    publisher="Audible" \
    year="2011" \
    media="download" \
    file1="ActiveSetupN.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Audible/Bin/Manager.exe" \
    homepage="http://www.audible.com"

load_audible()
{
    w_download http://download.audible.com/AM50/ActiveSetupN.exe 49f501471912ccca442bcc1c8f2c69160579f712
    cd "$W_CACHE/$W_PACKAGE"
    # Use exact title match!
    w_ahk_do "
        SetWinDelay 500
        SetTitleMatchMode, 3
        Run, $file1
        WinWait, AudibleManager Setup
        ControlClick, Button3  ; accept
        WinWait, AudibleManager Setup, Start by
        ControlClick, Button6 ; OK
        WinWaitClose
        ; many windows come and go, quite a few of them starting with AudibleManager, so use exact match to get the real mccoy
        WinWait, AudibleManager  ; the dang thing starts up
        WinKill
    "
}

#----------------------------------------------------------------

w_metadata audibledm apps \
    title="Audible.com Download Manager" \
    publisher="Audible" \
    year="2011" \
    media="download" \
    file1="AudibleDM_iTunesSetup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Audible/Bin/AudibleDownloadHelper.exe" \
    homepage="http://www.audible.com"

load_audibledm()
{
    w_download http://download.audible.com/AM50/AudibleDM_iTunesSetup.exe 03261d77a59ebbceedf6683b5301c162bc0c7788
    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetWinDelay 500
        SetTitleMatchMode, 2
        Run, AudibleDM_iTunesSetup.exe
        WinWait, Audible Download Manager Setup
        ControlClick, Button2  ; accept
        WinWait, Audible Download Manager Setup, Choose where
        ControlClick, Button1 ; OK
        WinWait, Audible Download Manager Setup, Manage
        ControlClick, Button1 ; OK
        WinWait, Audible Download Manager Setup, success
        ControlClick, Button1 ; OK
        WinWaitClose
        WinWait, Audible Download Manager  ; the dang thing starts up
        WinKill
    "
}

#----------------------------------------------------------------

w_metadata autohotkey apps \
    title="AutoHotKey" \
    publisher="autohotkey.org" \
    year="2010" \
    media="download" \
    file1="AutoHotkey104805_Install.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/AutoHotkey/AutoHotkey.exe"

load_autohotkey()
{
    W_BROWSERAGENT=1 \
    w_download http://www.autohotkey.com/download/AutoHotkey104805_Install.exe 13e5a9ca6d5b7705f1cd02560c3af4d38b1904fc
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" AutoHotkey104805_Install.exe $W_UNATTENDED_SLASH_S
}

#----------------------------------------------------------------

w_metadata cmake apps \
    title="CMake 2.8" \
    publisher="Kitware" \
    year="2013" \
    media="download" \
    file1="cmake-2.8.11.2-win32-x86.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/CMake 2.8/bin/cmake-gui.exe"

load_cmake()
{
    w_download http://www.cmake.org/files/v2.8/cmake-2.8.11.2-win32-x86.exe d79af5715c0ad48d78bb731cce93b5ad89b16512
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" cmake-2.8.11.2-win32-x86.exe $W_UNATTENDED_SLASH_S
}

#----------------------------------------------------------------

w_metadata colorprofile apps \
    title="Standard RGB color profile" \
    publisher="Microsoft" \
    year="2005" \
    media="download" \
    file1="ColorProfile.exe" \
    installed_exe1="c:/windows/system32/spool/drivers/color/sRGB Color Space Profile.icm"

load_colorprofile()
{
    w_download http://download.microsoft.com/download/whistler/hwdev1/1.0/wxp/en-us/ColorProfile.exe 6b72836b32b343c82d0760dff5cb51c2f47170eb
    w_try_unzip "$W_TMP" "$W_CACHE"/colorprofile/ColorProfile.exe

    # It's in system32 for both win32/win64
    mkdir -p "$W_WINDIR_UNIX"/system32/spool/drivers/color
    w_try cp -f "$W_TMP/sRGB Color Space Profile.icm" "$W_WINDIR_UNIX"/system32/spool/drivers/color
}

#----------------------------------------------------------------

w_metadata controlpad apps \
    title="MS ActiveX Control Pad" \
    publisher="Microsoft" \
    year="1997" \
    media="download" \
    file1="setuppad.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/ActiveX Control Pad/PED.EXE"

load_controlpad()
{
    # http://msdn.microsoft.com/en-us/library/ms968493.aspx
    w_call wsh57
    w_download http://download.microsoft.com/download/activexcontrolpad/install/4.0.0.950/win98mexp/en-us/setuppad.exe 8921e0f52507ca6a373c94d222777c750fb48af7
    w_try_cabextract --directory="$W_TMP" "$W_CACHE"/controlpad/setuppad.exe

    echo "If setup says 'Unable to start DDE ...', press Ignore"

    cd "$W_TMP"
    w_try "$WINE" setup $W_UNATTENDED_SLASH_QT

    if ! test -f "$W_SYSTEM32_DLLS"/FM20.DLL
    then
        w_die "Install failed.  Please report,  If you just wanted fm20.dll, try installing art2min instead."
    fi
}

#----------------------------------------------------------------

w_metadata controlspy apps \
    title="Control Spy 2.0 " \
    publisher="Microsoft" \
    year="2005" \
    media="download" \
    file1="ControlSpy.msi" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft/ControlSpy/ControlSpyV6.exe"

load_controlspy()
{
    w_download http://download.microsoft.com/download/a/3/1/a315b133-03a8-4845-b428-ec585369b285/ControlSpy.msi efe33701f78b5853ba73353f028b777b4c849e77
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" msiexec /i ControlSpy.msi ${W_UNATTENDED_SLASH_QB}
}

#----------------------------------------------------------------

# dxdiag is a system component that one usually adds to an existing wineprefix,
# so it belongs in 'dlls', not apps.
w_metadata dxdiag dlls \
    title="DirectX Diagnostic Tool" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="../directx9/directx_feb2010_redist.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/dxdiag.exe"

load_dxdiag()
{
    helper_directx_dl

    w_call gmdls

    w_try_cabextract -d "$W_TMP" -L -F dxnt.cab "$W_CACHE"/directx9/$DIRECTX_NAME
    w_try_cabextract -d "$W_SYSTEM32_DLLS" -L -F "dxdiag.exe" "$W_TMP/dxnt.cab"
    mkdir -p "$W_WINDIR_UNIX/help"
    w_try_cabextract -d "$W_WINDIR_UNIX/help" -L -F "dxdiag.chm" "$W_TMP/dxnt.cab"
    w_override_dlls native dxdiag.exe

    if w_workaround_wine_bug 1429
    then
        w_call dxdiagn
    fi
    if w_workaround_wine_bug 9027
    then
        w_call directmusic
    fi
}

#----------------------------------------------------------------

w_metadata emu8086 apps \
    title="emu8086" \
    publisher="emu8086.com" \
    year="2015" \
    media="download" \
    file1="emu8086v408r11.zip" \
    installed_exe1="c:/emu8086/emu8086.exe"

load_emu8086()
{
    w_download http://www.emu8086.com/files/emu8086v408r11.zip aa71b46ee9259e5b31a300c820277e551969da7b
    w_try_unzip "$W_TMP" "$W_CACHE/$W_PACKAGE"/$file1
    w_try "$WINE" "$W_TMP/Setup.exe" $W_UNATTENDED_SLASH_SILENT
}

#----------------------------------------------------------------

w_metadata ev3 apps \
    title="Lego Mindstorms EV3 Home Edition" \
    publisher="Lego" \
    year="2014" \
    media="download" \
    file1="LMS-EV3-WIN32-ENUS-01-02-01-full-setup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/LEGO Software/LEGO MINDSTORMS EV3 Home Edition/MindstormsEV3.exe"

load_ev3()
{
    if w_workaround_wine_bug 40192 "Installing vcrun2005 as Wine does not have MFC80.dll"
    then
        w_call vcrun2005
    fi

    if w_workaround_wine_bug 40193 "Installing IE8 is built-in Gecko is not sufficient"
    then
        w_call ie8
    fi

    w_call dotnet40

    # 2016-02-18: LMS-EV3-WIN32-ENUS-01-01-01-full-setup.exe 855c914d9a3cf0f4793a046872658fd661389671
    # 2016-03-22: LMS-EV3-WIN32-ENUS-01-02-01-full-setup.exe f4f077befd837e8f5716dbd134dc6828d6c4cc77

    w_download http://esd.lego.com.edgesuite.net/digitaldelivery/mindstorms/6ecda7c2-1189-4816-b2dd-440e22d65814/public/LMS-EV3-WIN32-ENUS-01-02-01-full-setup.exe f4f077befd837e8f5716dbd134dc6828d6c4cc77

    if [ $W_UNATTENDED_SLASH_Q ]
    then
        quiet="$W_UNATTENDED_SLASH_QB /AcceptLicenses yes"
    else
        quiet=""
    fi

    cd "$W_CACHE"/"$W_PACKAGE"
    w_try "$WINE" "$file1" ${quiet}

    if w_workaround_wine_bug 40729 "Setting override for urlmon.dll to native to avoid crash"
    then
        w_override_dlls native urlmon
    fi

    if w_workaround_wine_bug 34897 "Installing update KB2936068 to work around bug 34897" 1.9.10,
    then
        w_call ie8_kb2936068
    fi
}

#----------------------------------------------------------------

w_metadata firefox apps \
    title="Firefox 39.0" \
    publisher="Mozilla" \
    year="2015" \
    media="download" \
    file1="FirefoxSetup39.0.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Mozilla Firefox/firefox.exe"

load_firefox()
{
    w_download "https://download.mozilla.org/?product=firefox-39.0-SSL&os=win&lang=en-US" 75eccbd9b2d44210b551c9a5045f03f01e899528 "$file1"
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" "$file1" ${W_OPT_UNATTENDED:+ -ms}
}

#----------------------------------------------------------------

w_metadata fontxplorer apps \
    title="Font Xplorer 1.2.2" \
    publisher="Moon Software" \
    year="2001" \
    media="download" \
    file1="Font_Xplorer_122_Free.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/Font Xplorer/FXplorer.exe" \
    homepage="http://www.moonsoftware.com/fxplorer.asp"

load_fontxplorer()
{
    w_download http://www.moonsoftware.com/files/legacy/Font_Xplorer_122_Free.exe 22feb63be28730cbfad5458b139464490a25a68d

    cd "$W_CACHE/fontxplorer"
    w_try "$WINE" Font_Xplorer_122_Free.exe $W_UNATTENDED_SLASH_S
}

#----------------------------------------------------------------

w_metadata foobar2000 apps \
    title="foobar2000 v1.3.10" \
    publisher="Peter Pawlowski" \
    year="2014" \
    media="manual_download" \
    file1="foobar2000_v1.3.10.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/foobar2000/foobar2000.exe"

load_foobar2000()
{
    w_download_manual http://www.foobar2000.org/download foobar2000_v1.3.10.exe d4d60effc26d3ead48ba6f9c5ad32b9066231807
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" $file1 $W_UNATTENDED_SLASH_S
}

#----------------------------------------------------------------

w_metadata iceweasel apps \
    title="GNU Icecat 31.7.0" \
    publisher="GNU Foundation" \
    year="2015" \
    media="download" \
    file1="icecat-31.7.0.en-US.win32.zip" \
    installed_exe1="$W_PROGRAMS_X86_WIN/icecat/icecat.exe"

load_iceweasel()
{
    w_download https://ftp.gnu.org/gnu/gnuzilla/31.7.0/icecat-31.7.0.en-US.win32.zip cf52a728c1af29065b7dc7bdddc9265a79eb5328
    w_try_unzip "${W_PROGRAMS_X86_UNIX}" "${W_CACHE}/${W_PACKAGE}/${file1}"
}


#----------------------------------------------------------------

w_metadata irfanview apps \
    title="Irfanview" \
    publisher="Irfan Skiljan" \
    year="2014" \
    media="download" \
    file1="iview438_setup.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/IrfanView/i_view32.exe" \
    homepage="http://www.irfanview.com/"

load_irfanview()
{
    w_download http://fossies.org/windows/misc/iview438_setup.exe c55c2fd91ac1af03e8063442b110ba771357d42e
    if w_workaround_wine_bug 657 "Installing mfc42"
    then
        w_call mfc42
    fi

    cd "$W_CACHE/$W_PACKAGE"
    if test "$W_OPT_UNATTENDED"
    then
        w_ahk_do "
            SetWinDelay 200
            SetTitleMatchMode, 2
            run $file1
            winwait, Setup, This program will install
            winactivate, Setup, This program will install
            Sleep 900
            ControlClick, Button7 ; Uncheck All
            Sleep 900
            ControlClick, Button11 ; Next
            Sleep 900
            winwait, Setup, version
            Sleep 900
            ControlClick, Button11 ; Next
            Sleep 900
            winwait, Setup, associate extensions
            Sleep 900
            ControlClick, Button1 ; Images Only associations
            Sleep 900
            ControlClick, Button16 ; Next
            Sleep 900
            winwait, Setup, Search
            Sleep 900
            ControlClick, Button1 ; deselect chrome googsrch
            Sleep 900
            ControlClick, Button18 ; Next
            Sleep 1000
            winwait, Setup, INI
            Sleep 1000
            ControlClick, Button23 ; Next
            Sleep 1000
            winwait, Setup, You want to change
            winactivate, Setup, really
            Sleep 900
            ControlClick, Button1 ; Yes
            Sleep 900
            winwait, Setup, successful
            winactivate, Setup, successful
            Sleep 900
            ControlClick, Button2 ; no start irfanview
            Sleep 900
            ControlClick, Button27 ; done
            Sleep 900
            winwaitclose
        "
    else
        w_try "$WINE" $file1
    fi
}

#----------------------------------------------------------------

# FIXME: ie6 always installs to C:/Program Files even if LANG is de_DE.utf-8,
# so we have to hard code that, but that breaks on 64-bit Windows.
w_metadata ie6 dlls \
    title="Internet Explorer 6" \
    publisher="Microsoft" \
    year="2002" \
    media="download" \
    file1="ie60.exe" \
    installed_file1="c:/Program Files/Internet Explorer/iedetect.dll"

load_ie6()
{
    # Installer doesn't support Win64, and I can't find a x64 version on microsoft.com
    if [ $W_ARCH = win64 ]
    then
        w_die "This package does not work on a 64-bit installation"
    fi

    w_download http://download.oldapps.com/Internet_Explorer/ie60.exe 8e483db28ff01a7cabd39147ab6c59753ea1f533

    cd "$W_TMP"
    "$WINE" "$W_CACHE"/"$W_PACKAGE"/$file1

    w_call msls31

    # Unregister Wine IE
    if [ ! -f "$W_SYSTEM32_DLLS"/plugin.ocx ]
    then
        w_override_dlls builtin iexplore.exe
        w_try "$WINE" iexplore -unregserver
    fi

    # Change the override to the native so we are sure we use and register them
    w_override_dlls native,builtin iexplore.exe inetcpl.cpl itircl itss jscript mlang mshtml msimtf shdoclc shdocvw shlwapi

    # Remove the fake DLLs, if any
    mv "$W_PROGRAMS_UNIX"/"Internet Explorer"/iexplore.exe "$W_PROGRAMS_UNIX"/"Internet Explorer"/iexplore.exe.bak
    for dll in itircl itss jscript mlang mshtml msimtf shdoclc shdocvw shlwapi
    do
        test -f "$W_SYSTEM32_DLLS"/$dll.dll &&
        mv "$W_SYSTEM32_DLLS"/$dll.dll "$W_SYSTEM32_DLLS"/$dll.dll.bak
    done

    # The installer doesn't want to install iexplore.exe in XP mode.
    w_set_winver win2k

    # Workaround http://bugs.winehq.org/show_bug.cgi?id=21009
    # See also http://code.google.com/p/winezeug/issues/detail?id=78
    rm -f "$W_SYSTEM32_DLLS"/browseui.dll "$W_SYSTEM32_DLLS"/inseng.dll

    # Otherwise regsvr32 crashes later
    rm -f "$W_SYSTEM32_DLLS"/inetcpl.cpl

    # Work around http://bugs.winehq.org/show_bug.cgi?id=25432
    w_try_cabextract -F inseng.dll "$W_TMP/IE 6.0 Full/ACTSETUP.CAB"
    mv inseng.dll "$W_SYSTEM32_DLLS"
    w_override_dlls native inseng

    cd "$W_TMP/IE 6.0 Full"
    if [ $W_UNATTENDED_SLASH_Q ]
    then
        "$WINE" IE6SETUP.EXE /q:a /r:n /c:"ie6wzd /S:""#e"" /q:a /r:n"
    else
        "$WINE" IE6SETUP.EXE
    fi

    # IE6 exits with 194 to signal a reboot
    status=$?
    case $status in
    0|194) ;;
    *) w_die ie6 installation failed
    esac

    # Work around DLL registration bug until ierunonce/RunOnce/wineboot is fixed
    # FIXME: whittle down this list
    cd "$W_SYSTEM32_DLLS"
    for i in actxprxy.dll browseui.dll browsewm.dll cdfview.dll ddraw.dll \
      dispex.dll dsound.dll iedkcs32.dll iepeers.dll iesetup.dll imgutil.dll \
      inetcomm.dll inetcpl.cpl inseng.dll isetup.dll jscript.dll laprxy.dll \
      mlang.dll mshtml.dll mshtmled.dll msi.dll msident.dll \
      msoeacct.dll msrating.dll mstime.dll msxml3.dll occache.dll \
      ole32.dll oleaut32.dll olepro32.dll pngfilt.dll quartz.dll \
      rpcrt4.dll rsabase.dll rsaenh.dll scrobj.dll scrrun.dll \
      shdocvw.dll shell32.dll vbscript.dll webcheck.dll \
      wshcon.dll wshext.dll asctrls.ocx hhctrl.ocx mscomct2.ocx \
      plugin.ocx proctexe.ocx tdc.ocx webcheck.dll wshom.ocx
    do
        "$WINE" regsvr32 /i $i > /dev/null 2>&1
    done

    # Set windows version back to user's default. Leave at win2k for better rendering (is there a bug for that?)
    w_unset_winver

    # the ie6 we use these days lacks pngfilt, so grab that
    w_call pngfilt
}

#----------------------------------------------------------------

w_metadata ie7 dlls \
    title="Internet Explorer 7" \
    publisher="Microsoft" \
    year="2008" \
    media="download" \
    file1="IE7-WindowsXP-x86-enu.exe" \
    installed_file1="c:/windows/ie7.log"

load_ie7()
{
    # Unregister Wine IE
    if grep -q -i "wine placeholder" "$W_PROGRAMS_X86_UNIX/Internet Explorer/iexplore.exe"
    then
        w_override_dlls builtin iexplore.exe
        w_try "$WINE" iexplore -unregserver
    fi

    # Change the override to the native so we are sure we use and register them
    w_override_dlls native,builtin itircl itss jscript mshtml msimtf shdoclc shdocvw shlwapi urlmon wininet xmllite

    # IE7 installer will check the version number of iexplore.exe which causes IE7 installer to fail on wine-1.9.0+
    w_override_dlls native iexplore.exe

    # Bundled updspapi cannot work on Wine
    w_override_dlls builtin updspapi

    # Remove the fake DLLs from the existing WINEPREFIX
    if [ -f "$W_PROGRAMS_X86_UNIX/Internet Explorer/iexplore.exe" ]
    then
        mv "$W_PROGRAMS_X86_UNIX/Internet Explorer/iexplore.exe" "$W_PROGRAMS_X86_UNIX/Internet Explorer/iexplore.exe.bak"
    fi
    for dll in itircl itss jscript mshtml msimtf shdoclc shdocvw shlwapi urlmon
    do
        test -f "$W_SYSTEM32_DLLS"/$dll.dll &&
        mv "$W_SYSTEM32_DLLS"/$dll.dll "$W_SYSTEM32_DLLS"/$dll.dll.bak
    done

    # See http://bugs.winehq.org/show_bug.cgi?id=16013
    # Find instructions to create this file in dlls/wintrust/tests/crypt.c
    w_download https://github.com/Winetricks/winetricks/raw/master/files/winetest.cat ac8f50dd54d011f3bb1dd79240dae9378748449f

    # Put a dummy catalog file in place
    mkdir -p "$W_SYSTEM32_DLLS"/catroot/\{f750e6c3-38ee-11d1-85e5-00c04fc295ee\}
    w_try cp -f "$W_CACHE"/ie7/winetest.cat "$W_SYSTEM32_DLLS"/catroot/\{f750e6c3-38ee-11d1-85e5-00c04fc295ee\}/oem0.cat

    # KLUDGE: if / is writable (as on OS X?), having a Z: mapping to it
    # causes ie7 to put temporary directories on Z:\
    # so hide it temporarily.  This is not very robust!
    if test -w /
    then
        rm -f "$WINEPREFIX/dosdevices/z:.bak_wt"
        mv "$WINEPREFIX/dosdevices/z:" "$WINEPREFIX/dosdevices/z:.bak_wt"
    fi

    # Install
    w_download http://download.microsoft.com/download/3/8/8/38889DC1-848C-4BF2-8335-86C573AD86D9/IE7-WindowsXP-x86-enu.exe d39b89c360fbaa9706b5181ae4718100687a5326
    cd "$W_CACHE/$W_PACKAGE"

    "$WINE" IE7-WindowsXP-x86-enu.exe $W_UNATTENDED_SLASH_QUIET

    # IE7 exits with 194 to signal a reboot
    status=$?
    case $status in
    0) ;;
    105) echo "exit status $status - normal, user selected 'restart now'" ;;
    194) echo "exit status $status - normal, user selected 'restart later'" ;;
    *) w_die "exit status $status - $W_PACKAGE installation failed" ;;
    esac

    if test -w /
    then
        # END KLUDGE: restore Z:, assuming user didn't kill us
        mv "$WINEPREFIX/dosdevices/z:.bak_wt" "$WINEPREFIX/dosdevices/z:"
    fi

    # Work around DLL registration bug until ierunonce/RunOnce/wineboot is fixed
    # FIXME: whittle down this list
    cd "$W_SYSTEM32_DLLS"
    for i in actxprxy.dll browseui.dll browsewm.dll cdfview.dll ddraw.dll \
      dispex.dll dsound.dll iedkcs32.dll iepeers.dll iesetup.dll \
      imgutil.dll inetcomm.dll inseng.dll isetup.dll jscript.dll laprxy.dll \
      mlang.dll mshtml.dll mshtmled.dll msi.dll msident.dll \
      msoeacct.dll msrating.dll mstime.dll msxml3.dll occache.dll \
      ole32.dll oleaut32.dll olepro32.dll pngfilt.dll quartz.dll \
      rpcrt4.dll rsabase.dll rsaenh.dll scrobj.dll scrrun.dll \
      shdocvw.dll shell32.dll urlmon.dll vbscript.dll webcheck.dll \
      wshcon.dll wshext.dll asctrls.ocx hhctrl.ocx mscomct2.ocx \
      plugin.ocx proctexe.ocx tdc.ocx webcheck.dll wshom.ocx
    do
        "$WINE" regsvr32 /i $i > /dev/null 2>&1
    done

    # Seeing is believing
    case $WINETRICKS_GUI in
    none)
        w_warn "To start ie7, use the command "$WINE" '${W_PROGRAMS_WIN}\\\\Internet Explorer\\\\iexplore'"
        ;;
    *)
        w_warn "Starting ie7.  To start it later, use the command "$WINE" '${W_PROGRAMS_WIN}\\\\Internet Explorer\\\\iexplore'"
        "$WINE" "${W_PROGRAMS_WIN}\\Internet Explorer\\iexplore" http://www.microsoft.com/windows/internet-explorer/ie7/ > /dev/null 2>&1 &
        ;;
    esac
}

#----------------------------------------------------------------

w_metadata ie8 dlls \
    title="Internet Explorer 8" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="IE8-WindowsXP-x86-ENU.exe" \
    installed_file1="c:/windows/ie8_main.log"

load_ie8()
{
    # Unregister Wine IE
    if grep -q -i "wine placeholder" "$W_PROGRAMS_X86_UNIX/Internet Explorer/iexplore.exe"
    #if [ ! -f "$W_SYSTEM32_DLLS"/plugin.ocx ]
    then
        w_override_dlls builtin iexplore.exe
        w_try "$WINE" iexplore -unregserver
    fi

    w_call msls31

    # Change the override to the native so we are sure we use and register them
    w_override_dlls native,builtin itircl itss jscript msctf mshtml shdoclc shdocvw shlwapi urlmon wininet xmllite

    # IE8 installer will check the version number of iexplore.exe which causes IE8 installer to fail on wine-1.9.0+
    w_override_dlls native iexplore.exe

    # Bundled updspapi cannot work on Wine
    w_override_dlls builtin updspapi

    # Remove the fake DLLs from the existing WINEPREFIX
    if [ -f "$W_PROGRAMS_X86_UNIX/Internet Explorer/iexplore.exe" ]
    then
        mv "$W_PROGRAMS_X86_UNIX/Internet Explorer/iexplore.exe" "$W_PROGRAMS_X86_UNIX/Internet Explorer/iexplore.exe.bak"
    fi
    for dll in browseui.dll inseng.dll itircl itss jscript msctf mshtml shdoclc shdocvw shlwapi urlmon
    do
        test -f "$W_SYSTEM32_DLLS"/$dll.dll &&
        mv "$W_SYSTEM32_DLLS"/$dll.dll "$W_SYSTEM32_DLLS"/$dll.dll.bak
    done

    # See http://bugs.winehq.org/show_bug.cgi?id=16013
    # Find instructions to create this file in dlls/wintrust/tests/crypt.c
    w_download https://github.com/Winetricks/winetricks/raw/master/files/winetest.cat ac8f50dd54d011f3bb1dd79240dae9378748449f

    # Put a dummy catalog file in place
    mkdir -p "$W_SYSTEM32_DLLS"/catroot/\{f750e6c3-38ee-11d1-85e5-00c04fc295ee\}
    w_try cp -f "$W_CACHE"/ie8/winetest.cat "$W_SYSTEM32_DLLS"/catroot/\{f750e6c3-38ee-11d1-85e5-00c04fc295ee\}/oem0.cat

    w_download http://download.microsoft.com/download/C/C/0/CC0BD555-33DD-411E-936B-73AC6F95AE11/IE8-WindowsXP-x86-ENU.exe e489483e5001f95da04e1ebf3c664173baef3e26
    if [ $W_UNATTENDED_SLASH_QUIET ]
    then
        quiet="$W_UNATTENDED_SLASH_QUIET /forcerestart"
    else
        quiet=""
    fi
    cd "$W_CACHE/$W_PACKAGE"

    # KLUDGE: if / is writable, having a Z: mapping to it causes ie8 to put temporary directories on Z:\
    # so hide it temporarily.  This is not very robust!
    rm -f "$WINEPREFIX/dosdevices/z:.bak_wt"
    mv "$WINEPREFIX/dosdevices/z:" "$WINEPREFIX/dosdevices/z:.bak_wt"

    # FIXME: There's an option for /updates-noupdates to disable checking for updates, but that
    # forces the install to fail on Wine. Not sure if it's an IE8 or Wine bug...
    # FIXME: can't check status, as it always reports failure on wine?
    "$WINE" IE8-WindowsXP-x86-ENU.exe $quiet
    # END KLUDGE: restore Z:, assuming user didn't kill us
    mv "$WINEPREFIX/dosdevices/z:.bak_wt" "$WINEPREFIX/dosdevices/z:"

    # Work around DLL registration bug until ierunonce/RunOnce/wineboot is fixed
    # FIXME: whittle down this list
    cd "$W_SYSTEM32_DLLS"
    for i in actxprxy.dll browseui.dll browsewm.dll cdfview.dll ddraw.dll \
      dispex.dll dsound.dll iedkcs32.dll iepeers.dll iesetup.dll \
      imgutil.dll inetcomm.dll isetup.dll jscript.dll laprxy.dll \
      mlang.dll msctf.dll mshtml.dll mshtmled.dll msi.dll msimtf.dll msident.dll \
      msoeacct.dll msrating.dll mstime.dll msxml3.dll occache.dll \
      ole32.dll oleaut32.dll olepro32.dll pngfilt.dll quartz.dll \
      rpcrt4.dll rsabase.dll rsaenh.dll scrobj.dll scrrun.dll \
      shdocvw.dll shell32.dll urlmon.dll vbscript.dll webcheck.dll \
      wshcon.dll wshext.dll asctrls.ocx hhctrl.ocx mscomct2.ocx \
      plugin.ocx proctexe.ocx tdc.ocx uxtheme.dll webcheck.dll wshom.ocx
    do
        "$WINE" regsvr32 /i $i > /dev/null 2>&1
    done

    if w_workaround_wine_bug 25648 "Setting TabProcGrowth=0 to avoid hang"
    then
        cat > "$W_TMP"/set-tabprocgrowth.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Microsoft\Internet Explorer\Main]
"TabProcGrowth"=dword:00000000

_EOF_
        w_try_regedit "$W_TMP_WIN"\\set-tabprocgrowth.reg
    fi

    # Seeing is believing
    case $WINETRICKS_GUI in
    none)
        w_warn "To start ie8, use the command "$WINE" '${W_PROGRAMS_WIN}\\\\Internet Explorer\\\\iexplore'"
        ;;
    *)
        w_warn "Starting ie8.  To start it later, use the command "$WINE" '${W_PROGRAMS_WIN}\\\\Internet Explorer\\\\iexplore'"
        "$WINE" "${W_PROGRAMS_WIN}\\Internet Explorer\\iexplore" http://www.microsoft.com/windows/internet-explorer > /dev/null 2>&1 &
        ;;
    esac
}

#----------------------------------------------------------------

w_metadata kobo apps \
    title="Kobo e-book reader" \
    publisher="Kobo" \
    year="2011" \
    media="download" \
    file1="KoboSetup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Kobo/Kobo.exe" \
    homepage="http://www.borders.com/online/store/MediaView_ereaderapps"

load_kobo()
{
    w_download http://download.kobobooks.com/desktop/1/KoboSetup.exe 31a5f5583edf4b716b9feacb857d2170104cabd9
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" $file1 ${W_OPT_UNATTENDED:+ /S}
}

#----------------------------------------------------------------

w_metadata mingw apps \
    title="Minimalist GNU for Windows, including GCC for Windows" \
    publisher="GNU" \
    year="2013" \
    media="download" \
    file1="mingw-get-setup.exe" \
    installed_exe1="c:/MinGW/bin/gcc.exe" \
    homepage="http://mingw.org/wiki/Getting_Started"

load_mingw()
{
    w_download "$WINETRICKS_SOURCEFORGE/mingw/files/mingw-get-setup.exe" 66f1355f16ac1e328243e877880eb6e45e8b30e2

    cd "$W_CACHE/mingw"
    w_try "$WINE" "$file1"

    w_append_path 'C:\MinGW\bin'
    w_try "$WINE" mingw-get update
    w_try "$WINE" mingw-get install gcc msys-base
}

#----------------------------------------------------------------

w_metadata mpc apps \
    title="Media Player Classic - Home Cinema" \
    publisher="doom9 folks" \
    year="2014" \
    media="download" \
    file1="MPC-HC.1.7.5.x86.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/MPC-HC/mpc-hc.exe" \
    homepage="http://mpc-hc.sourceforge.net"

load_mpc()
{
    w_download $WINETRICKS_SOURCEFORGE/project/mpc-hc/MPC%20HomeCinema%20-%20Win32/MPC-HC_v1.7.5_x86/MPC-HC.1.7.5.x86.exe 39f90869929007ae0576ae30dca6cd22ed5a59c2
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" MPC-HC.1.7.5.x86.exe ${W_OPT_UNATTENDED:+ /VERYSILENT}
}

#----------------------------------------------------------------

w_metadata mspaint apps \
    title="MS Paint" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="WindowsXP-KB978706-x86-ENU.exe" \
    installed_file1="c:/windows/mspaint.exe"

load_mspaint()
{
    if w_workaround_wine_bug 657 "Native mspaint.exe from XP requires mfc42.dll"
    then
        w_call mfc42
    fi
    w_download http://download.microsoft.com/download/0/A/4/0A40DF5C-2BAE-4C63-802A-84C33B34AC98/WindowsXP-KB978706-x86-ENU.exe f4e076b3867c2f08b6d258316aa0e11d6822b8d7
    w_try $WINE "$W_CACHE"/mspaint/WindowsXP-KB978706-x86-ENU.exe /q /x:"$W_TMP"/WindowsXP-KB978706-x86-ENU
    w_try cp -f "$W_TMP"/WindowsXP-KB978706-x86-ENU/SP3GDR/mspaint.exe "$W_WINDIR_UNIX"/mspaint.exe
}

#----------------------------------------------------------------

w_metadata mt4 apps \
    title="Meta Trader 4" \
    year="2005" \
    media="download" \
    file1="mt4setup.exe"

load_mt4()
{
    w_download https://download.mql5.com/cdn/web/metaquotes.software.corp/mt4/mt4setup.exe

    if w_workaround_wine_bug 7156 "${title} needs wingdings.ttf, installing opensymbol"
    then
        w_call opensymbol
    fi

    # Opens a webpage
    WINEDLLOVERRIDES="winebrowser.exe="
    export WINEDLLOVERRIDES

    # No documented silent install option, unfortunately..
    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        Run, ${file1}
        WinWait, MetaTrader 4 Setup, license agreement
        ControlClick, Button1
        Sleep 100
        ControlClick, Button3
        WinWait, MetaTrader 4 Setup, Installation successfully completed
        ControlClick, Button4
        Process, Wait, terminal.exe
        Process, Close, terminal.exe
    "
}

#----------------------------------------------------------------

w_metadata nook apps \
    title="Nook for PC (e-book reader)" \
    publisher="Barnes & Noble" \
    year="2011" \
    media="download" \
    file1="bndr2_setup_latest.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Barnes & Noble/BNDesktopReader/BNDReader.exe" \
    homepage="http://www.barnesandnoble.com/u/free-nook-apps/379002321/"

load_nook()
{
    # Dates from curl --head
    # 10 Feb 2011 sha1sum 4a06a529b93ed33c3518326d874b40d8d7b70e7a
    # 7 Oct 2011 sha1sum 3b0301bd55471cc47cced44501547411fac9fcea
    # 7 Mar 2012 sha1sum e7060a63b9b303ddd820de762d9df254e1c931bc
    w_download http://images.barnesandnoble.com/PResources/download/eReader2/bndr2_setup_latest.exe e7060a63b9b303ddd820de762d9df254e1c931bc
    cd "$W_CACHE/$W_PACKAGE"
    "$WINE" $file1 ${W_OPT_UNATTENDED:+ /S}
    # normally has exit status 199?
}

#----------------------------------------------------------------

w_metadata npp apps \
    title="Notepad++" \
    publisher="Don Ho" \
    year="2015" \
    media="download" \
    file1="npp.6.7.9.2.Installer.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Notepad++/notepad++.exe"

load_npp()
{
    w_download https://notepad-plus-plus.org/repository/6.x/6.7.9.2/npp.6.7.9.2.Installer.exe 34574fb2e4e06ff941061bf444b57ce926ce23d7
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" "${file1}" $W_UNATTENDED_SLASH_S
}

#----------------------------------------------------------------

w_metadata office2003pro apps \
    title="Microsoft Office 2003 Professional" \
    publisher="Microsoft" \
    year="2002" \
    media="cd" \
    file1="setup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft Office/Office11/WINWORD.EXE"

load_office2003pro()
{
    w_mount OFFICE11
    w_read_key

    w_ahk_do "
        if ( w_opt_unattended > 0 ) {
            run ${W_ISO_MOUNT_LETTER}:setup.exe /EULA_ACCEPT=YES /PIDKEY=$W_KEY
        } else {
            run ${W_ISO_MOUNT_LETTER}:setup.exe
        }
        SetTitleMatchMode, 2
        WinWait,Microsoft Office 2003 Setup, Welcome
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            WinWait,Microsoft Office 2003 Setup,Key
            Sleep 500
            ControlClick Button1 ; Next
            WinWait,Microsoft Office 2003 Setup,Initials
            Sleep 500
            ControlClick Button1 ; Next
            WinWait,Microsoft Office 2003 Setup,End-User
            Sleep 500
            ControlClick Button1 ; I accept
            ControlClick Button2 ; Next
            WinWait,Microsoft Office 2003 Setup,Recommended
            Sleep 500
            ControlClick Button7 ; Next
            WinWait,Microsoft Office 2003 Setup,Summary
            Sleep 500
            ControlClick Button1 ; Install
        }
        WinWait,Microsoft Office 2003 Setup,Completed
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick Button2 ; Finish
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata office2007pro apps \
    title="Microsoft Office 2007 Professional" \
    publisher="Microsoft" \
    year="2006" \
    media="cd" \
    file1="setup.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/Microsoft Office/Office12/WINWORD.EXE"

load_office2007pro()
{
    if w_workaround_wine_bug 14980 "Using native riched20"
    then
        w_override_app_dlls winword.exe n riched20
        w_override_app_dlls excel.exe n riched20
        w_override_app_dlls powerpnt.exe n riched20
        w_override_app_dlls msaccess.exe n riched20
        w_override_app_dlls outlook.exe n riched20
        w_override_app_dlls mspub.exe n riched20
        w_override_app_dlls infopath.exe n riched20
    fi

    w_mount OFFICE12
    w_read_key

    if test $W_OPT_UNATTENDED
    then
        # See
        # http://blogs.technet.com/b/office_resource_kit/archive/2009/01/29/configure-a-silent-install-of-the-2007-office-system-with-config-xml.aspx
        # http://www.symantec.com/connect/articles/office-2007-silent-installation-lessons-learned
        cat > "$W_TMP"/config.xml <<__EOF__
<Configuration Product="ProPlus">
<Display Level="none" CompletionNotice="no" SuppressModal="yes" AcceptEula="yes" />
<PIDKEY Value="$W_KEY" />
</Configuration>
__EOF__
        "$WINE" ${W_ISO_MOUNT_LETTER}:setup.exe /config "$W_TMP_WIN"\\config.xml

        status=$?
        case $status in
        0|43) ;;
        78)
            w_die "Installing $W_PACKAGE failed, product key $W_KEY \
might be wrong. Try again without -q, or put correct key in \
$W_CACHE/$W_PACKAGE/key.txt and rerun."
            ;;
        *)
            w_die "Installing $W_PACKAGE failed."
            ;;
        esac

    else
        w_try "$WINE" ${W_ISO_MOUNT_LETTER}:setup.exe
    fi
}

#----------------------------------------------------------------

w_metadata opera apps \
    title="Opera 11" \
    publisher="Opera Software" \
    year="2011" \
    media="download" \
    file1="Opera_1150_en_Setup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Opera/opera.exe"

load_opera()
{
    w_download ftp://ftp.opera.com/pub/opera/win/1150/en/Opera_1150_en_Setup.exe df50c7aed50e92af858e8834f833dd0543014b46
    cd "$W_CACHE"/$W_PACKAGE
    w_try "$WINE" $file1 ${W_OPT_UNATTENDED:+ /silent /launchopera 0 /allusers}
}

#----------------------------------------------------------------

w_metadata picasa39 apps \
    title="Picasa 3.9" \
    publisher="Google" \
    year="2014" \
    file1="picasa39-setup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Google/Picasa3/Picasa3.exe"

load_picasa39()
{
    # 2015/01/17: 39b2df46dbc423e250371e826026a2827f55b956
    # 2015/09/21: 55907fc84b1d9d6a450463869b16927f07737298
    # 2016/01/02: b3f7e2ee168811cb1d924eb34afe2b0d8153f89f

    w_download http://dl.google.com/picasa/picasa39-setup.exe b3f7e2ee168811cb1d924eb34afe2b0d8153f89f
    if w_workaround_wine_bug 29434 "Picasa 3.9 fails to authenticate with Google"
    then
        w_warn "Picasa 3.9 authentication to the Google account is currently broken under wine. See http://bugs.winehq.org/show_bug.cgi?id=29434 for more details."
    fi
    cd "$W_CACHE"/$W_PACKAGE
    w_ahk_do "
        SetTitleMatchMode, 2
        run picasa39-setup.exe
        WinWait, Picasa 3 Setup
        if ( w_opt_unattended > 0 ) {
             Sleep 1000
             ControlClick Button2 ;I Agree - License
             Sleep 1000
             WinWait, Picasa 3 Setup, Choose Install Location
             ControlClick Button2 ;Install
             Sleep 1000
             WinWait, Picasa 3 Setup, Picasa 3 has been installed on your computer
             Sleep 500
             ControlClick Button5 ; Desktop Icon
             Sleep 500
             ControlClick Button6 ; Quick Launch
             Sleep 500
             ControlClick Button7 ; Default search off
             Sleep 500
             ControlClick Button8 ; Usage statistics sent
             Sleep 500
             ControlClick Button4 ; Run Picasa
             Sleep 500
             ControlClick Button2 ; Finish
        }
        WinWaitClose
        "
}

#----------------------------------------------------------------

w_metadata protectionid apps \
    title="Protection ID" \
    publisher="CDKiLLER & TippeX" \
    year="2015" \
    media="download" \
    file1="ProtectionId.670.halloween.2015.rar" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/protection_id.exe"

load_protectionid()
{
    w_download http://pid.gamecopyworld.com/dl.php?f=ProtectionId.670.halloween.2015.rar a307e15f28d00959cffddd8fda073aac6df943c8 "$file1"
    cd "$W_SYSTEM32_DLLS"
    w_try_unrar "${W_CACHE}/${W_PACKAGE}/${file1}"
    # ProtectionId.670.halloween.2015 has a different executable name than usual, this may need to be disabled on next update:
    mv Protection_ID.eXe protection_id.exe
}

#----------------------------------------------------------------

w_metadata psdk2003 apps \
    title="MS Platform SDK 2003" \
    publisher="Microsoft" \
    year="2003" \
    media="download" \
    file1="5.2.3790.1830.15.PlatformSDK_Svr2003SP1_rtm.img" \
    installed_file1="$W_PROGRAMS_X86_WIN/Microsoft Platform SDK/SetEnv.Cmd"

load_psdk2003()
{
    w_call mfc42

    # http://www.microsoft.com/en-us/download/details.aspx?id=15656
    w_download http://download.microsoft.com/download/7/5/e/75ec7f04-4c8c-4f38-b582-966e76602643/5.2.3790.1830.15.PlatformSDK_Svr2003SP1_rtm.img

    # Unpack ISO (how handy that 7z can do this!)
    # Only the windows version of 7z can handle .img files?
    WINETRICKS_OPT_SHAREDPREFIX=1 w_call 7zip
    cd "$W_PROGRAMS_X86_UNIX"/7-Zip
    w_try "$WINE" 7z.exe x -y -o"$W_TMP_WIN" "$W_CACHE_WIN\\psdk2003\\5.2.3790.1830.15.PlatformSDK_Svr2003SP1_rtm.img"

    cd "$W_TMP/Setup"

    # Sanity check...
    w_verify_sha1sum 6376ab5394226f426366d0646bf244d26156697b  PSDK-x86.msi

    w_try "$WINE" msiexec /i PSDK-x86.msi ${W_UNATTENDED_SLASH_QB}
}

#----------------------------------------------------------------

w_metadata psdkwin7 apps \
    title="MS Windows 7 SDK" \
    publisher="Microsoft" \
    year="2009" \
    media="download" \
    file1="winsdk_web.exe" \
    installed_exe1="C:/Program Files/Microsoft SDKs/Windows/v7.0/Bin/SetEnv.Cmd"

load_psdkwin7()
{
    # http://www.microsoft.com/downloads/details.aspx?FamilyID=c17ba869-9671-4330-a63e-1fd44e0e2505&displaylang=en
    w_call dotnet20
    w_call mfc42   # need mfc42u, or setup will abort
    # don't have a working unattended recipe.  Maybe we'll have to
    # do an AutoHotKey script until Microsoft gets its act together:
    # http://social.msdn.microsoft.com/Forums/en-US/windowssdk/thread/c053b616-7d5b-405d-9841-ec465a8e21d5
    w_download http://download.microsoft.com/download/7/A/B/7ABD2203-C472-4036-8BA0-E505528CCCB7/winsdk_web.exe a01dcc67a38f461e80ea649edf1353f306582507
    cd "$W_CACHE/$W_PACKAGE"
    if w_workaround_wine_bug 21596
    then
        w_warn "When given a choice, select only C++ compilers and headers, the other options don't work yet.  See http://bugs.winehq.org/show_bug.cgi?id=21596"
    fi
    w_try "$WINE" winsdk_web.exe

    if w_workaround_wine_bug 21362
    then
        # Assume user installed in default location
        cat > "$W_TMP"/set-psdk7.reg <<_EOF_
REGEDIT4

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows]
"CurrentVersion"="v7.0"
"CurrentInstallFolder"="C:\\\Program Files\\\Microsoft SDKs\\\Windows\\\v7.0\\\"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.0]
"InstallationFolder"="C:\\\Program Files\\\Microsoft SDKs\\\Windows\\\v7.0\\\"
"ProductVersion"="7.0.7600.16385.40715"
"ProductName"="Microsoft Windows SDK for Windows 7 (7.0.7600.16385.40715)"
_EOF_
        w_try_regedit "$W_TMP_WIN"\\set-psdk7.reg
    fi
}

#----------------------------------------------------------------

w_metadata psdkwin71 apps \
    title="MS Windows 7.1 SDK" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="winsdk_web.exe" \
    installed_exe1="C:/Program Files/Microsoft SDKs/Windows/v7.1/Bin/SetEnv.Cmd"

load_psdkwin71()
{
    w_call dotnet20
    w_call dotnet40
    w_call mfc42   # need mfc42u, or setup will abort
    # http://www.microsoft.com/downloads/details.aspx?FamilyID=c17ba869-9671-4330-a63e-1fd44e0e2505&displaylang=en
    w_download http://download.microsoft.com/download/A/6/A/A6AC035D-DA3F-4F0C-ADA4-37C8E5D34E3D/winsdk_web.exe a8717ebb20a69c7efa85232bcb9899b8b07f98cf

    if w_workaround_wine_bug 21596
    then
        w_warn "When given a choice, select only C++ compilers and headers, the other options don't work yet.  See http://bugs.winehq.org/show_bug.cgi?id=21596"
    fi

    # don't have a working unattended recipe.  Maybe we'll have to
    # do an AutoHotKey script until Microsoft gets its act together:
    # http://social.msdn.microsoft.com/Forums/en-US/windowssdk/thread/c053b616-7d5b-405d-9841-ec465a8e21d5
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" winsdk_web.exe

    if w_workaround_wine_bug 21362
    then
        # Assume user installed in default location
        cat > "$W_TMP"/set-psdk71.reg <<_EOF_
REGEDIT4

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows]
"CurrentVersion"="v7.1"
"CurrentInstallFolder"="C:\\\Program Files\\\Microsoft SDKs\\\Windows\\\v7.1\\\"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1]
"InstallationFolder"="C:\\\Program Files\\\Microsoft SDKs\\\Windows\\\v7.1\\\"
"ProductVersion"="7.0.7600.0.30514"
"ProductName"="Microsoft Windows SDK for Windows 7 (7.0.7600.0.30514)"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1\WinSDKBuild]
"ComponentName"="Microsoft Windows SDK Headers and Libraries"
"InstallationFolder"="C:\\\Program Files\\\Microsoft SDKs\\\Windows\\\v7.1\\\"
"ProductVersion"="7.0.7600.0.30514"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1\WinSDKTools]
"ComponentName"="Microsoft Windows SDK Headers and Libraries"
"InstallationFolder"="C:\\\Program Files\\\Microsoft SDKs\\\Windows\\\v7.1\\\bin\\\"
"ProductVersion"="7.0.7600.0.30514"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1\WinSDKWin32Tools]
"ComponentName"="Microsoft Windows SDK Utilities for Win32 Development"
"InstallationFolder"="C:\\\Program Files\\\Microsoft SDKs\\\Windows\\\v7.1\\\bin\\\"
"ProductVersion"="7.0.7600.0.30514"
_EOF_
        w_try_regedit "$W_TMP_WIN"\\set-psdk71.reg
    fi
}

#----------------------------------------------------------------

w_metadata python26 dlls \
    title="Python interpreter 2.6.2" \
    publisher="Python Software Foundaton" \
    year="2009" \
    media="download" \
    file1="python-2.6.2.msi" \
    installed_exe1="c:/Python26/python.exe"

load_python26()
{
    w_download http://www.python.org/ftp/python/2.6.2/python-2.6.2.msi 2d1503b0e8b7e4c72a276d4d9027cf4856b208b8
    w_download $WINETRICKS_SOURCEFORGE/project/pywin32/pywin32/Build%20214/pywin32-214.win32-py2.6.exe eca58f29b810d8e3e7951277ebb3e35ac35794a3

    if [ "$WINETRICKS_WINE_VERSION" = "wine-1.4.1" ]
    then
        w_die "This installer is broken under $WINETRICKS_WINE_VERSION. Please upgrade Wine. See https://code.google.com/p/winetricks/issues/detail?id=347 for more info."
    fi

    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" msiexec /i python-2.6.2.msi ALLUSERS=1 $W_UNATTENDED_SLASH_Q

    w_ahk_do "
        SetTitleMatchMode, 2
        run pywin32-214.win32-py2.6.exe
        WinWait, Setup, Wizard will install pywin32
        if ( w_opt_unattended > 0 ) {
             ControlClick Button2   ; next
             WinWait, Setup, Python 2.6 is required
             ControlClick Button3   ; next
             WinWait, Setup, Click Next to begin
             ControlClick Button3   ; next
             WinWait, Setup, finished
             ControlClick Button4   ; Finish
        }
        WinWaitClose
        "
}

#----------------------------------------------------------------

w_metadata spotify apps \
    title="Spotify - All the music, all the time" \
    publisher="Spotify" \
    year="2011" \
    media="download" \
    file1="SpotifyInstaller.exe" \
    installed_exe1="c:/users/$LOGNAME/Application Data/Spotify/spotify.exe"

load_spotify()
{
    #             0.4.9  f26712b576baa1c78112a05474293deef39f7f62
    # 29 Apr 2011 0.4.10 4becb04f8ad08a3ff59d6830bf1d998fcca1815b
    # 7 may 2011         a3c7daecf1051c4aaab544e6b66753617c0706b1
    # updates too frequently to check checksum :-(
    w_download http://www.spotify.com/download/Spotify%20Installer.exe

    cd "$W_CACHE/$W_PACKAGE"
    # w_download doesn't handle renaming for us without a checksum, tsk.
    # And AutoHotKey thinks % is a variable reference.
    if test ! -f SpotifyInstaller.exe
    then
        cp Spotify%20Installer.exe SpotifyInstaller.exe
    fi

    # Install is silent by default, and always starts app
    # So all we have to do here is close app if we want unattended install
    w_ahk_do "
        SetTitleMatchMode, 2
        run SpotifyInstaller.exe
        WinWait, ahk_class SpotifyMainWindow
        if ( w_opt_unattended > 0 ) {
            WinClose
        }
        WinWaitClose
        sleep 1000
        Process, Close, SpotifyWebHelper.exe
        "
}

#----------------------------------------------------------------

w_metadata safari apps \
    title="Safari" \
    publisher="Apple" \
    year="2010" \
    media="download" \
    file1="SafariSetup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Safari/Safari.exe"

load_safari()
{
    w_download http://appldnld.apple.com.edgesuite.net/content.info.apple.com/Safari5/061-7138.20100607.Y7U87/SafariSetup.exe e56d5d79d9cfbb85ac46ac78aa497d7f3d8dbc3d

    if test $W_OPT_UNATTENDED
    then
        w_warn "Safari's silent install is broken under Wine. See http://bugs.winehq.org/show_bug.cgi?id=23493. You should do a regular install if you want to use Safari."
    fi

    cd "$W_CACHE"/$W_PACKAGE
    w_try "$WINE" SafariSetup.exe $W_UNATTENDED_SLASH_QN
}

#----------------------------------------------------------------

w_metadata sketchup apps \
    title="SketchUp 8" \
    publisher="Google" \
    year="2012" \
    media="download" \
    file1="GoogleSketchUpWEN.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Google/Google SketchUp 8/SketchUp.exe"

load_sketchup()
{
    w_download http://dl.google.com/sketchup/GoogleSketchUpWEN.exe f0628e6f05241f91e4f36d6be3b8685a408ad12b

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run GoogleSketchUpWEN.exe
        WinWait, SketchUp, Welcome
        if ( w_opt_unattended > 0 ) {
            Sleep 4000
            Send {Enter}
            WinWait, SketchUp, License
            Sleep 1000
            ControlClick Button1 ; accept
            Sleep 1000
            ControlClick Button4 ; Next
            WinWait, SketchUp, Destination
            Sleep 1000
            ControlClick Button1 ; Next
            WinWait, SketchUp, Ready
            Sleep 1000
            ControlClick Button1 ; Install
        }
        WinWait, SketchUp, Completed
        if ( w_opt_unattended > 0 ) {
            Sleep 1000
            ControlClick Button1 ; Finish
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata steam apps \
    title="Steam" \
    publisher="Valve" \
    year="2010" \
    media="download" \
    file1="SteamInstall.msi" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Steam/Steam.exe"

load_steam()
{
    # 18 Mar 2011 7f2fee9ffeaba8424a6c76d6c95b794735ac9959
    # 29 Nov 2012 fa053c268b6285741d1a1392c25f92c5cb2a6ffb
    # 17 Mar 2014 b2a3fdbe4a662f3bf751f5b8bfc61f8d35e050fe
    # 11 Dec 2014 7ad8fbeffa6c963b821f80129c15c9d8e85f9a4a
    #  6 Jan 2015 e04aefe8bc894f11f211edec8e8a008abe0147d2
    # 21 Jun 2015 0e8046d40c38d817338135ec73a5b217cc340cf5
    # 29 Dec 2015 728e3c82fd57c68cbbdb64965719081ffee6272c
    w_download http://media.steampowered.com/client/installer/SteamSetup.exe 728e3c82fd57c68cbbdb64965719081ffee6272c
    cd "$W_CACHE/$W_PACKAGE"

    # Should be fixed in newer steam versions, since 2012. Commenting out for a while before removing in case users need to revert locally
    #
    # Install corefonts first, so if the user doesn't have cabextract/Wine with cab support, we abort before installing Steam.
    # FIXME: support using Wine's cab support
    #if ! test -f "$W_FONTSDIR_UNIX/Times.TTF" && \
    #    w_workaround_wine_bug 22751 "Installing corefonts to prevent a Steam crash"
    #then
    #    w_call corefonts
    #fi

    if test $W_OPT_UNATTENDED
    then
            w_ahk_do "
            run, SteamSetup.exe
            SetTitleMatchMode, 2
            WinWait, Steam, Using Steam
            ControlClick, Button2
            WinWait, Steam, Please review
            ControlClick, Button4
            sleep 1000
            ControlClick, Button2
            WinWait, Steam, Select the language
            ControlClick, Button2
            WinWait, Steam, Choose the folder
            ControlClick, Button2
            WinWait, Steam, Steam has been installed
            ControlClick, Button4
            sleep 1000
            ControlClick, Button2
            WinWaitClose
            "
    else
            w_try "$WINE" SteamSetup.exe
    fi

    # Not all users need this disabled, but let's play it safe for now
    if w_workaround_wine_bug 22053 "Disabling gameoverlayrenderer to prevent game crashes on some machines."
    then
        w_override_dlls disabled gameoverlayrenderer
    fi
}

#----------------------------------------------------------------

w_metadata uplay apps \
    title="Uplay" \
    publisher="Ubisoft" \
    year="2013" \
    media="download" \
    file1="UplayInstaller.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Ubisoft/Ubisoft Game Launcher/Uplay.exe"

load_uplay()
{
    # 4 June 2013 3.0.1 sha1sum fdb9e736b5b2211fb23b35d30d52deae6f4b32a4
    # 1 July 2013 3.1.0 sha1sum 21a7f469534dd1463eaaab6b2be2fa9084bceea2
    # 11 Nov 2013 4.0   sha1sum 52e287f9f78313e4713d2f070b15734410da0c5a
    # 26 Dec 2013 4.2   sha1sum ada2c11ee62eee19f8b1661bd974862e336623c6
    # 16 Feb 2014 ?     sha1sum 19f98632ad1ff330c647f8ff1a3a15b44238c709
    # Changes too frequently, don't check anymore
    w_download http://static3.cdn.ubi.com/orbit/launcher_installer/UplayInstaller.exe
    cd "$W_CACHE/$W_PACKAGE"

    # NSIS installer
    w_try "$WINE" UplayInstaller.exe ${W_OPT_UNATTENDED:+ /S}

    if w_workaround_wine_bug 33673 "Installing gdiplus to work around slow navigation"
    then
        w_call gdiplus
    fi
}

#----------------------------------------------------------------

w_metadata utorrent apps \
    title="µTorrent 2.2.1" \
    publisher="BitTorrent" \
    year="2011" \
    media="manual_download" \
    file1="utorrent_2.2.1.exe" \
    installed_exe1="c:/windows/utorrent.exe"

load_utorrent()
{
    # BitTorrent client supported on Windows, OS X, Linux through Wine
    # Oct 2010 2.0.4 sha1sum 8382b8a7bc625d68b6efe18a7b9e5488dc0119ee
    # Nov 6 2010 2.0.4 sha1sum 263a91693d0976473cd321cd6f1b0103a814f3ad
    # Dev 17 2010 2.2 sha1sum 0c95bdfba07421fe706b30ee2ec6779217c5dce4, hangs, see Wine bug 24946
    # Feb 11 2011 2.2.1beta sha1sum 82e81e1484b4e8654b83908509f3777532c6fcb3
    # Mar 28 2011 2.2.1 sha1sum 7049109e4d3f72338d54b42ae37ecf38fafed46f
    # Apr 14 2011 2.2.1 sha1sum b1378d7cbe5d1e1b168ce44def8f59facdc046d5
    # 7 May 2011        sha1sum 2932c9ed1c1225e485f7e3dd2ed267aa7d568c80
    # 14 May 2011 removed checksum, updates too quickly to track :-(
    # 7 Mar 2012 sha1sum c6d9a80c02898139b17194d10293f17ecef054cb
    w_download_manual "http://www.oldapps.com/utorrent.php?old_utorrent=38" utorrent_2.2.1.exe c6d9a80c02898139b17194d10293f17ecef054cb

    w_try cp -f "$W_CACHE/utorrent/$file1" "$W_WINDIR_UNIX"/utorrent.exe
}

#----------------------------------------------------------------

w_metadata utorrent3 apps \
    title="µTorrent 3.1" \
    publisher="BitTorrent" \
    year="2011" \
    media="download" \
    file1="uTorrent.exe" \
    installed_exe1="c:/users/$LOGNAME/Application Data/uTorrent/uTorrent.exe"

load_utorrent3()
{
    # 15 Apr 2011: sha1sum a5f198207919e8f2091a9b4459d7d6fc8a63e874
    # 27 Apr 2011: sha1sum d969f0c61cf2b2afaea4121f097ef690dffbf771
    # 7 May 2011: sha1sum 1793a7b15d905a9fa82f9a969a96fa53abaac04c
    # 14 May: removed checksum, changes too often to track
    # 7 Mar 2012: sha1sum 73ba69b5d0004239a709af5db57c88c9d9c8f7b2
    # 28 Jun 2013: sha1sum d2408c8a09a2bd9704af39f818ec7ac9e9cca46e
    w_download http://download-new.utorrent.com/endpoint/utorrent/os/windows/track/stable/ d2408c8a09a2bd9704af39f818ec7ac9e9cca46e uTorrent.exe

    cd "$W_CACHE/$W_PACKAGE"
    # If you don't use /PERFORMINSTALL, it just runs µTorrent
    # FIXME: That's no longer a quiet option, though..
    "$WINE" $file1 /PERFORMINSTALL /NORUN

    # dang installer exits with status 1 on success
    status=$?
    case $status in
    0|1) ;;
    *) w_die "Note: utorrent installer returned status '$status'.  Aborting." ;;
    esac
}

#----------------------------------------------------------------

w_metadata vc2005express apps \
    title="MS Visual C++ 2005 Express" \
    publisher="Microsoft" \
    year="2005" \
    media="download" \
    file1="VC.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft Visual Studio 8/Common7/IDE/VCExpress.exe"

load_vc2005express()
{
    # Thanks to http://blogs.msdn.com/astebner/articles/551674.aspx for the recipe
    w_call dotnet20

    # http://blogs.msdn.com/b/astebner/archive/2006/03/14/551674.aspx
    # http://go.microsoft.com/fwlink/?linkid=57034
    w_download http://download.microsoft.com/download/A/9/1/A91D6B2B-A798-47DF-9C7E-A97854B7DD18/VC.iso 1ae44e4eaf8c61c3a39e573fd6efd9889e940529

    # Unpack ISO (how handy that 7z can do this!)
    w_try_7z "$W_TMP" "$W_CACHE"/vc2005express/VC.iso

    cd "$W_TMP"
    if [ $W_UNATTENDED_SLASH_Q ]
    then
        chmod +x Ixpvc.exe
        # Add /qn after ReallySuppress for a really silent install (but then you won't see any errors)

        w_try "$WINE" Ixpvc.exe /t:"$W_TMP_WIN" /q:a /c:"msiexec /i vcsetup.msi VSEXTUI=1 ADDLOCAL=ALL REBOOT=ReallySuppress"

    else
        w_try "$WINE" setup.exe
        w_ahk_do "
            SetTitleMatchMode, 2
            WinWait, Visual C++ 2005 Express Edition Setup
            WinWaitClose, Visual C++ 2005 Express Edition Setup
        "
    fi
}

#----------------------------------------------------------------

w_metadata vc2005expresssp1 apps \
    title="MS Visual C++ 2005 Express SP1" \
    publisher="Microsoft" \
    year="2007" \
    media="download" \
    file1="VS80sp1-KB926748-X86-INTL.exe"

load_vc2005expresssp1()
{
    w_call vc2005express

    # http://www.microsoft.com/downloads/details.aspx?FamilyId=7B0B0339-613A-46E6-AB4D-080D4D4A8C4E
    if w_workaround_wine_bug 37375
        then
            w_warn "Installer currently fails"
    fi
    w_download http://download.microsoft.com/download/7/7/3/7737290f-98e8-45bf-9075-85cc6ae34bf1/VS80sp1-KB926748-X86-INTL.exe 8b9a0172efad64774aa122f29e093ad2043b308d
    w_try $WINE "$W_CACHE"/vc2005expresssp1/VS80sp1-KB926748-X86-INTL.exe
}

#----------------------------------------------------------------

w_metadata vc2005trial apps \
    title="MS Visual C++ 2005 Trial" \
    publisher="Microsoft" \
    year="2005" \
    media="download" \
    file1="En_vs_2005_vsts_180_Trial.img" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft Visual Studio 8/Common7/IDE/devenv.exe"

load_vc2005trial()
{
    w_call dotnet20
    
    # Without mfc42.dll, pidgen.dll won't load, and the app claims "A trial edition is already installed..."
    w_call mfc42

    w_download http://download.microsoft.com/download/6/f/5/6f5f7a01-50bb-422d-8742-c099c8896969/En_vs_2005_vsts_180_Trial.img f66ae07618d67e693ca0524d3582208c20e07823

    # Unpack ISO (how handy that 7z can do this!)
    # Only the windows version of 7z can handle .img files?
    WINETRICKS_OPT_SHAREDPREFIX=1 w_call 7zip
    cd "$W_PROGRAMS_X86_UNIX"/7-Zip
    w_try "$WINE" 7z.exe x -y -o"$W_TMP_WIN" "$W_CACHE_WIN\\vc2005trial\\En_vs_2005_vsts_180_Trial.img"

    cd "$W_TMP"

    # Sanity check...
    w_verify_sha1sum 15433993ab7573c5154dbea2dcb65450f2adbf5c vs/wcu/runmsi.exe

    cd vs/Setup
    w_ahk_do "
        SetTitleMatchMode 2
        run setup.exe
        winwait, Visual Studio, Setup is loading
        if ( w_opt_unattended > 0 ) {
            winwait, Visual Studio, Loading completed
            controlclick, button2
            winwait, Visual Studio, Select features
            controlclick, button38
            controlclick, button40
            winwait, Visual Studio, You have chosen
            controlclick, button1
            winwait, Visual Studio, Select features
            controlclick, button11
        }
        ;this can take a while
        winwait, Finish Page
        if ( w_opt_unattended > 0 )
            controlclick, button2
        winwaitclose, Finish Page
    "
}

#----------------------------------------------------------------

w_metadata vc2008express apps \
    title="MS Visual C++ 2008 Express" \
    publisher="Microsoft" \
    year="2008" \
    media="download" \
    file1="VS2008ExpressENUX1397868.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft Visual Studio 9.0/Common7/IDE/VCExpress.exe"

load_vc2008express()
{
    w_call dotnet35

    # This is the version without SP1 baked in.  (SP1 requires dotnet35sp1, which doesn't work yet.)
    w_download http://download.microsoft.com/download/8/B/5/8B5804AD-4990-40D0-A6AA-CE894CBBB3DC/VS2008ExpressENUX1397868.iso 76c6d28274a67741da720744026ea991a70867d1

    # Unpack ISO
    w_try_7z "$W_TMP" "$W_CACHE"/vc2008express/VS2008ExpressENUX1397868.iso

    # See also http://blogs.msdn.com/b/astebner/archive/2008/04/25/8425198.aspx
    cd "$W_TMP"/VCExpress
    w_try "$WINE" setup.exe $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata vc2010express apps \
    title="MS Visual C++ 2010 Express" \
    publisher="Microsoft" \
    year="2010" \
    media="download" \
    file1="VS2010Express1.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft Visual Studio 10.0/Common7/IDE/VCExpress.exe"

load_vc2010express()
{
    w_download http://download.microsoft.com/download/1/E/5/1E5F1C0A-0D5B-426A-A603-1798B951DDAE/VS2010Express1.iso adef5e361a1f64374f520b9a2d03c54ee43721c6

    # Unpack ISO
    w_try_7z "$W_TMP" "$W_CACHE"/vc2010express/VS2010Express1.iso
    cd "$W_TMP"/VCExpress

    # dotnet40 leaves winver at win2k, which causes vc2010 to abort on
    # start because it looks for c:\users\$LOGNAME\Application Data
    w_set_winver winxp

    if w_workaround_wine_bug 12501 "Installing mspatcha to work around bug in SQL Server install"
    then
        w_call mspatcha
    fi

    if w_workaround_wine_bug 34627 "Installing Visual C++ 2005 managed runtime to work around bug in SQL Server install"
    then
        w_call vcrun2005
    fi

    w_try $WINE setup.exe $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

w_metadata vlc apps \
    title="VLC media player 2.2.1" \
    publisher="VideoLAN" \
    year="2015" \
    media="download" \
    file1="vlc-2.2.1-win32.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/VideoLAN/VLC/vlc.exe" \
    homepage="http://www.videolan.org/vlc/"

load_vlc()
{
    w_download http://get.videolan.org/vlc/2.2.1/win32/vlc-2.2.1-win32.exe 4cbcea9764b6b657d2147645eeb5b973b642530e
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" $file1 ${W_OPT_UNATTENDED:+ /S}
}

#----------------------------------------------------------------

w_metadata winamp apps \
    title="Winamp" \
    publisher="Radionomy (AOL (Nullsoft))" \
    year="2013" \
    media="download" \
    file1="winamp5666_full_all_redux.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Winamp/winamp.exe" \
    homepage="http://www.winamp.com"

load_winamp()
{
    w_info "may send information while installing, see http://www.microsoft.com/security/portal/Threat/Encyclopedia/Entry.aspx?threatid=159633"
    # 2014 winamp5621_full_emusic-7plus_en-us.exe afc172039db52fdc202114bec7bcf8b5bf2468bb

    w_download http://winampplugins.co.uk/Winamp/winamp5666_full_all_redux.exe 136314be0da42ed399b88a106cb1f43093e2c0c2
    cd "$W_CACHE/$W_PACKAGE"
    if test $W_OPT_UNATTENDED
    then
        w_ahk_do "
            SetWinDelay 500
            SetTitleMatchMode, 2
            Run $file1
            WinWait, Installer Language, Please select
            Sleep 500
            ControlClick, Button1 ; OK
            WinWait, Winamp Installer, Welcome to the Winamp installer
            Sleep 500
            ControlClick, Button2 ; Next
            WinWait, Winamp Installer, License Agreement
            Sleep 500
            ControlClick, Button2 ; I Agree
            WinWait, Winamp Installer, Choose Install Location
            Sleep 500
            ControlClick, Button2 ; Next
            WinWait, Winamp Installer, Choose Components
            Sleep 500
            ControlClick, Button2 ; Next for Full install
            WinWait, Winamp Installer, Choose Start Options
            Sleep 500
            ControlClick, Button4 ; uncheck start menu entry
            Sleep 500
            ControlClick, Button5 ; uncheck ql icon
            Sleep 500
            ControlClick, Button6 ; uncheck deskto icon
            Sleep 500
            ControlClick, Button2 ; Install
            WinWait, Winamp Installer, Installation Complete
            Sleep 500
            ControlClick, Button4 ; uncheck launch when complete
            Sleep 500
            ControlClick, Button2 ; Finish
            WinWaitClose
        "
    else
        w_try "$WINE" "$file1"
    fi
}

#----------------------------------------------------------------

w_metadata wme9 apps \
    title="MS Windows Media Encoder 9 (broken in Wine)" \
    publisher="Microsoft" \
    year="2002" \
    media="download" \
    file1="WMEncoder.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/Windows Media Components/Encoder/wmenc.exe"

load_wme9()
{
    if [ $W_ARCH = win64 ]
    then
        w_die "Installer doesn't support 64-bit architecture."
    fi
    # See also http://www.microsoft.com/downloads/details.aspx?FamilyID=5691ba02-e496-465a-bba9-b2f1182cdf24
    w_download http://download.microsoft.com/download/8/1/f/81f9402f-efdd-439d-b2a4-089563199d47/WMEncoder.exe 7a3f8781f3e5705651992ef0150ee30bc1295116

    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" WMEncoder.exe $W_UNATTENDED_SLASH_Q
}

#----------------------------------------------------------------

# helper - not useful by itself
load_wm9codecs()
{
    # Note: must install WMP9 or 10 first, or installer will complain and abort.

    # See http://www.microsoft.com/downloads/details.aspx?FamilyID=06fcaab7-dcc9-466b-b0c4-04db144bb601
    # Used by direct calls from load_wmp9, so we have to specify cache directory.
    # http://birds.camden.rutgers.edu/
    w_download_to wm9codecs http://birds.camden.rutgers.edu/WM9Codecs9x.exe 8b76bdcbea0057eb12b7966edab4b942ddacc253
    cd "$W_CACHE/wm9codecs"
    w_set_winver win2k
    w_try "$WINE" WM9Codecs9x.exe $W_UNATTENDED_SLASH_Q
}

w_metadata wmp9 dlls \
    title="Windows Media Player 9" \
    publisher="Microsoft" \
    year="2003" \
    media="download" \
    file1="MPSetup.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN"/l3codeca.acm

load_wmp9()
{
    w_skip_windows wmp9 && return

    # Not really expected to work well yet; see
    # http://appdb.winehq.org/appview.php?versionId=1449

    if [ $W_ARCH = win64 ]
    then
        w_die "Installer doesn't support 64-bit architecture."
    fi

    w_call wsh57

    w_set_winver win2k

    # See also http://www.microsoft.com/windows/windowsmedia/player/9series/default.aspx
    w_download http://download.microsoft.com/download/1/b/c/1bc0b1a3-c839-4b36-8f3c-19847ba09299/MPSetup.exe 580536d10657fa3868de2869a3902d31a0de791b

    # remove builtin placeholders to allow update
    rm -f "$W_SYSTEM32_DLLS"/wmvcore.dll "$W_SYSTEM32_DLLS"/wmp.dll
    # need native wmp override to allow update and later checks to succeed
    w_override_dlls native wmp

    # FIXME: should we override quartz?  Builtin crashes when you play
    # anything, but maybe that's bug 30557 and only affects new systems?
    # Wine's pidgen is too stubby, crashes, see Wine bug 31111
    w_override_app_dlls MPSetup.exe native pidgen

    cd "$W_CACHE"/"$W_PACKAGE"
    w_try "$WINE" MPSetup.exe $W_UNATTENDED_SLASH_Q

    load_wm9codecs

    w_unset_winver
}

#----------------------------------------------------------------

w_metadata wmp10 dlls \
    title="Windows Media Player 10" \
    publisher="Microsoft" \
    year="2006" \
    media="download" \
    file1="MP10Setup.exe" \
    installed_file1="$W_SYSTEM32_DLLS_WIN/l3codecp.acm"

load_wmp10()
{
    if [ $W_ARCH = win64 ]
    then
        w_die "Installer doesn't support 64-bit architecture. Use a 32-bit WINEPREFIX instead."
    fi

    # FIXME: what versions of Windows are really bundled with wmp10?
    w_skip_windows wmp10 && return

    # See http://appdb.winehq.org/appview.php?iVersionId=3212
    w_call wsh57

    # http://www.microsoft.com/downloads/en/details.aspx?FamilyID=b446ae53-3759-40cf-80d5-cde4bbe07999
    w_download http://download.microsoft.com/download/1/2/a/12a31f29-2fa9-4f50-b95d-e45ef7013f87/MP10Setup.exe 69862273a5d9d97b4a2e5a3bd93898d259e86657

    # Crashes on exit, but otherwise ok; see http://bugs.winehq.org/show_bug.cgi?id=12633
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" MP10Setup.exe $W_UNATTENDED_SLASH_Q

    # Disable WMP's services, since they depend on unimplemented stuff, they trigger the GUI debugger several times
    w_try_regedit /D "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Cdr4_2K"
    w_try_regedit /D "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Cdralw2k"

    load_wm9codecs

    w_unset_winver
}

#----------------------------------------------------------------
# Benchmarks
#----------------------------------------------------------------

w_metadata 3dmark2000 benchmarks \
    title="3DMark2000" \
    publisher="MadOnion.com" \
    year="2000" \
    media="download" \
    file1="3dmark2000_v11_100308.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/MadOnion.com/3DMark2000/3DMark2000.exe"

load_3dmark2000()
{
    # http://www.futuremark.com/download/3dmark2000/
    if ! test -f "$W_CACHE/$W_PACKAGE/3dmark2000_v11_100308.exe"
    then
        w_download http://www.ocinside.de/download/3dmark2000_v11_100308.exe b0400d59cfd45d8c8893d3d4edc58b6285ee1502
    fi

    w_try_unzip "$W_TMP/$W_PACKAGE" "$W_CACHE/$W_PACKAGE"/3dmark2000_v11_100308.exe
    cd "$W_TMP/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run Setup.exe
        WinWait Welcome
        ;ControlClick Button1  ; Next
        Sleep 1000
        Send {Enter}           ; Next
        WinWait License
        ;ControlClick Button2  ; Yes
        Sleep 1000
        Send {Enter}           ; Yes
        ;WinWaitClose ahk_class #32770 ; License
        WinWait ahk_class #32770, Destination
        ;ControlClick Button1  ; Next
        Sleep 1000
        Send {Enter}           ; Next
        ;WinWaitClose ahk_class #32770 ; Destination
        WinWait, Start
        ;ControlClick Button1  ; Next
        Sleep 1000
        Send {Enter}           ; Next
        WinWait Registration
        ControlClick Button1  ; Next
        WinWait Complete
        Sleep 1000
        ControlClick Button1  ; Unclick View Readme
        ;ControlClick Button4  ; Finish
        Send {Enter}           ; Finish
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata 3dmark2001 benchmarks \
    title="3DMark2001" \
    publisher="MadOnion.com" \
    year="2001" \
    media="download" \
    file1="3dmark2001se_330_100308.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/MadOnion.com/3DMark2001 SE/3DMark2001SE.exe"

load_3dmark2001()
{
    # http://www.futuremark.com/download/3dmark2001/
    if ! test -f "$W_CACHE/$W_PACKAGE"/3dmark2001se_330_100308.exe
    then
        w_download http://www.ocinside.de/download/3dmark2001se_330_100308.exe 643bacbcc1615bb4f46d3b045b1b8d78371a6b54
    fi

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        run 3dmark2001se_330_100308.exe
        WinWait ahk_class #32770 ; welcome
        if ( w_opt_unattended > 0 ) {
            ControlClick Button2  ; Next
            sleep 5000
            WinWait ahk_class #32770 ; License
            ControlClick Button2  ; Next
            WinWait ahk_class #32770, Destination
            ControlClick Button1  ; Next
            WinWait ahk_class #32770, Start
            ControlClick Button1  ; Next
            WinWait,, Registration
            ControlClick Button2  ; Next
        }
        WinWait,, Complete
        if ( w_opt_unattended > 0 ) {
            ControlClick Button1  ; Unclick View Readme
            ControlClick Button4  ; Finish
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata 3dmark03 benchmarks \
    title="3D Mark 03" \
    publisher="Futuremark" \
    year="2003" \
    media="manual_download" \
    file1="3DMark03_v360_1901.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Futuremark/3DMark03/3DMark03.exe"

load_3dmark03()
{
    # http://www.futuremark.com/benchmarks/3dmark03/download/
    if ! test -f "$W_CACHE/$W_PACKAGE/3DMark03_v360_1901.exe"
    then
        w_download_manual http://www.futuremark.com/download/3dmark03/ 3DMark03_v360_1901.exe 46a439101ddbbe3c9563b5e9651cb61b46ce0619
    fi

    cd "$W_CACHE/$W_PACKAGE"
    w_warn "Don't use mouse while this installer is running.  Sorry..."
    # This old installer doesn't seem to be scriptable the usual way, so spray and pray.
    w_ahk_do "
        SetTitleMatchMode, 2
        run 3DMark03_v360_1901.exe
        WinWait 3DMark03 - InstallShield Wizard, Welcome
        if ( w_opt_unattended > 0 ) {
            WinActivate
            Send {Enter}
            Sleep 2000
            WinWait 3DMark03 - InstallShield Wizard, License
            WinActivate
            ; Accept license
            Send a
            Send {Enter}
            Sleep 2000
            ; Choose Destination
            Send {Enter}
            Sleep 2000
            ; Begin install
            Send {Enter}
            ; Wait for install to finish
            WinWait 3DMark03, Registration
            ; Purchase later
            Send {Tab}
            Send {Tab}
            Send {Enter}
        }
        WinWait, 3DMark03 - InstallShield Wizard, Complete
        if ( w_opt_unattended > 0 ) {
            ; Uncheck readme
            Send {Space}
            Send {Tab}
            Send {Tab}
            Send {Enter}
        }
        WinWaitClose, 3DMark03 - InstallShield Wizard, Complete
    "
}

#----------------------------------------------------------------

w_metadata 3dmark05 benchmarks \
    title="3D Mark 05" \
    publisher="Futuremark" \
    year="2005" \
    media="download" \
    file1="3dmark05_v130_1901.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Futuremark/3DMark05/3DMark05.exe"

load_3dmark05()
{
    # http://www.futuremark.com/download/3dmark05/
    if ! test -f "$W_CACHE/$W_PACKAGE/3DMark05_v130_1901.exe"
    then
        w_download http://www.ocinside.de/download/3dmark05_v130_1901.exe 8ad6bc2917e22edf5fc95d1fa96cc82515093fb2
    fi

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        run 3DMark05_v130_1901.exe
        WinWait ahk_class #32770, Welcome
        if ( w_opt_unattended > 0 ) {
            Send {Enter}
            WinWait, ahk_class #32770, License
            ControlClick Button1 ; Accept
            ControlClick Button4 ; Next
            WinWait, ahk_class #32770, Destination
            ControlClick Button1 ; Next
            WinWait, ahk_class #32770, Install
            ControlClick Button1 ; Install
            WinWait, ahk_class #32770, Purchase
            ControlClick Button4 ; Later
        }
        WinWait, ahk_class #32770, Complete
        if ( w_opt_unattended > 0 ) {
            ControlClick Button1 ; Uncheck view readme
            ControlClick Button3 ; Finish
        }
        WinWaitClose, ahk_class #32770, Complete
    "
    ARGS=""
    if w_workaround_wine_bug 22392
    then
        w_warn "You must run the app with the -nosysteminfo option to avoid a crash on startup"
        ARGS="-nosysteminfo"
    fi
}

#----------------------------------------------------------------

w_metadata 3dmark06 benchmarks \
    title="3D Mark 06" \
    publisher="Futuremark" \
    year="2006" \
    media="manual_download" \
    file1="3DMark06_v121_installer.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Futuremark/3DMark06/3DMark06.exe"

load_3dmark06()
{
    w_download_manual http://www.futuremark.com/support/downloads 3DMark06_v121_installer.exe a125a4b0a5649f848292f38cf424c672d8142058

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        run $file1
        WinWait ahk_class #32770, Welcome
        if ( w_opt_unattended > 0 ) {
            Send {Enter}
            WinWait, ahk_class #32770, License
            ControlClick Button1 ; Accept
            ControlClick Button4 ; Next
            WinWait, ahk_class #32770, Destination
            ControlClick Button1 ; Next
            WinWait, ahk_class #32770, Install
            ControlClick Button1 ; Install
            WinWait ahk_class OpenAL Installer
            ControlClick Button2 ; OK
            WinWait ahk_class #32770
            ControlClick Button1 ; OK
        }
        WinWait, ahk_class #32770, Complete
        if ( w_opt_unattended > 0 ) {
            ControlClick Button1 ; Uncheck view readme
            ControlClick Button3 ; Finish
        }
        WinWaitClose, ahk_class #32770, Complete
    "

    if w_workaround_wine_bug 24417 "Installing shader compiler..."
    then
        # "Demo" button doesn't work without this.  d3dcompiler_43 related.
        w_call d3dx9_28
        w_call d3dx9_36
    fi

    ARGS=""
    if w_workaround_wine_bug 22392
    then
        w_warn "You must run the app with the -nosysteminfo option to avoid a crash on startup"
        ARGS="-nosysteminfo"
    fi
}

#----------------------------------------------------------------

w_metadata unigine_heaven benchmarks \
    title="Unigen Heaven 2.1 Benchmark" \
    publisher="Unigen" \
    year="2010" \
    media="manual_download" \
    file1="Unigine_Heaven-2.1.msi"

load_unigine_heaven()
{
    # FIXME: use w_download_torrent()
    w_download_manual http://unigine.com/download/torrents/Unigine_Heaven-2.1.msi.torrent Unigine_Heaven-2.1.msi 3d7b94a3734cdae85f98032b61668e743979c444

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        run msiexec /i $file1
        if ( w_opt_unattended > 0 ) {
            WinWait ahk_class MsiDialogCloseClass
            Send {Enter}
            WinWait ahk_class MsiDialogCloseClass, License
            ControlClick Button1 ; Accept
            ControlClick Button3 ; Accept
            WinWait ahk_class MsiDialogCloseClass, Choose
            ControlClick Button1 ; Typical
            WinWait ahk_class MsiDialogCloseClass, Ready
            ControlClick Button2 ; Install
            ; FIXME: on systems with OpenAL already (Win7?), the next four lines
            ; are not needed.  We should somehow wait for either OpenAL window
            ; *or* Completed window.
            WinWait ahk_class OpenAL Installer
            ControlClick Button2 ; OK
            WinWait ahk_class #32770
            ControlClick Button1 ; OK
        }
        WinWait ahk_class MsiDialogCloseClass, Completed
        if ( w_opt_unattended > 0 ) {
            ControlClick Button1 ; Finish
            Send {Enter}
        }
        winwaitclose
    "
}

#----------------------------------------------------------------
# Games
#----------------------------------------------------------------

w_metadata algodoo_demo games \
    title="Algodoo Demo" \
    publisher="Algoryx" \
    year="2009" \
    media="download" \
    file1="Algodoo_1_7_1-Win32.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Algodoo/Algodoo.exe"

load_algodoo_demo()
{
    w_download http://www.algodoo.com/download/Algodoo_1_7_1-Win32.exe caa73e73669a8787652a6bed123bbe2682152f12

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        ; This one's funny... on Wine, keyboard works once you click manually, but until then, only ControlClick seems to work.
        run, Algodoo_1_7_1-Win32.exe
        SetTitleMatchMode, 2
        winwait, Algodoo, Welcome
        if ( w_opt_unattended > 0 ) {
            ControlClick, TNewButton1
            winwait, Algodoo, License
            ;send {Tab}a{Space}{Enter}
            ControlClick, TNewRadioButton1  ; Accept
            ControlClick, TNewButton2  ; Next
            winwait, Algodoo, Destination
            ;send {Enter}
            ControlClick, TNewButton3  ; Next
            winwait, Algodoo, Folder
            ;send {Enter}
            ControlClick, TNewButton4  ; Next
            winwait, Algodoo, Select Additional Tasks
            ;send {Enter}
            ControlClick, TNewButton4  ; Next
            winwait, Algodoo, Ready to Install
            ;send {Enter}
            ControlClick, TNewButton4  ; Next
        }
        winwait, Algodoo, Completing
        if ( w_opt_unattended > 0 ) {
            sleep 500
            send {Space}{Tab}{Space}{Tab}{Space}{Enter}   ; decline to run app or view tutorials
        }
        WinWaitClose, Algodoo, Completing
    "
}

#----------------------------------------------------------------

w_metadata amnesia_tdd_demo games \
    title="Amnesia: The Dark Descent Demo" \
    publisher="Frictional Games" \
    year="2010" \
    media="manual_download" \
    file1="amnesia_tdd_demo_1.0.1.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Amnesia - The Dark Descent Demo/redist/Amnesia.exe"

load_amnesia_tdd_demo()
{
    w_download_manual "http://www.amnesiagame.com/#demo" amnesia_tdd_demo_1.0.1.exe 0bf0bc6e9c8ea76f1c44582d9302a9b22d31d1b6

    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        SetTitleMatchMode, 2
        Run, amnesia_tdd_demo_1.0.1.exe
        if ( w_opt_unattended > 0 ) {
            WinWait,Select Setup Language, language
            ControlClick, TNewButton1
            WinWait, Amnesia - The Dark Descent Demo, Welcome
            ControlClick, TNewButton1
            WinWait, Amnesia - The Dark Descent Demo, License
            ControlClick, TNewRadioButton1
            ControlClick, TNewButton2
            WinWait, Amnesia - The Dark Descent Demo, installed?
            ControlClick, TNewButton3
            WinWait, Folder Does Not Exist, created
            ControlClick, Button1
            WinWait, Amnesia - The Dark Descent Demo, shortcuts
            ControlClick, TNewButton4
            WinWait, Amnesia - The Dark Descent Demo, additional tasks
            ControlClick, TNewButton4
            WinWait, Amnesia - The Dark Descent Demo, ready to begin installing
            ControlClick, TNewButton4
            WinWait, Amnesia - The Dark Descent Demo, finished
            ControlClick, TNewButton4
            WinWaitClose, Amnesia - The Dark Descent Demo, finished
        }
    "
}

#----------------------------------------------------------------

w_metadata aoe3_demo games \
    title="Age of Empires III Trial" \
    publisher="Microsoft" \
    year="2005" \
    media="download" \
    file1="aoe3trial.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft Games/Age of Empires III Trial/age3.exe"

load_aoe3_demo()
{

    w_download "http://download.microsoft.com/download/a/5/2/a525997e-8423-435b-b694-08118d235064/aoe3trial.exe" 2b0a123243092d79f910db5691d99d469f7c17c3

    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        SetTitleMatchMode, 2
        run aoe3trial.exe
        WinWait,Empires,Welcome
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            winactivate          ; else next button click ignored on vista?
            Sleep 500
            ControlClick Button1 ; Next
            WinWait,Empires,Please
            Sleep 500
            ControlClick Button4 ; Next
            WinWait,Empires,Complete
            Sleep 500
            ControlClick Button4 ; Finish
        }
        WinWaitClose
    "

    if w_workaround_wine_bug 24912
    then
        # kill off lingering installer
        w_ahk_do "
            SetTitleMatchMode, 2
            WinKill,Empires
        "
        # or should we just do $WINESERVER -k, like fable_tlc does?
        PID=`ps augxw | grep IDriver | grep -v grep | awk '{print $2}'`
        kill $PID
    fi
}

#----------------------------------------------------------------

w_metadata aoe_demo games \
    title="Age of Empires Demo" \
    publisher="Microsoft" \
    year="1997" \
    media="download" \
    file1="MSAoE.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft Games/Age of Empires Trial/empires.exe"

load_aoe_demo()
{
    w_download http://download.microsoft.com/download/aoe/Trial/1.0/WIN98/EN-US/MSAoE.exe 23630a65ce4133038107f3175f8fc54a914bc2f3

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        run, MSAoE.exe
        SetTitleMatchMode, 2
        winwait, Microsoft Age of Empires Trial Version
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            ControlClick, Button1
            winwait, End User License Agreement
            sleep 1000
            ControlClick, Button1
            winwait, Microsoft Age of Empires Trial Version, Setup will install
            sleep 1000
            ControlClick Button2
            winwait, Microsoft Age of Empires Trial Version, Setup has successfully
            sleep 1000
            ControlClick Button1
        }
        WinWaitClose, Microsoft Age of Empires Trial Version
    "
}

#----------------------------------------------------------------

w_metadata acreedbro games \
    title="Assassin's Creed Brotherhood" \
    publisher="Ubisoft" \
    year="2011" \
    media="dvd" \
    file1="ACB.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Ubisoft/Assassin's Creed Brotherhood/AssassinsCreedBrotherhood.exe"

load_acreedbro()
{
    w_mount ACB
    w_read_key
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        run ${W_ISO_MOUNT_LETTER}:setup.exe
        winwait, Brotherhood, Choose
        if ( w_opt_unattended > 0 ) {
            WinActivate
            send {Enter}
            ;ControlClick, Button3   ; Accept default (english)
            winwait, Brotherhood, Welcome
            WinActivate
            send {Enter}   ; Next
            winwait, Brotherhood, License
            WinActivate
            send a         ; Agree
            sleep 500
            send {Enter}   ; Next
            winwait, Brotherhood, begin
            send {Enter}   ; Install
        }
        winwait, Brotherhood, Finish
        if ( w_opt_unattended > 0 ) {
            ControlClick Button4
            send {Enter}   ; Finish
        }
        WinWaitClose
    "

    w_download http://static3.cdn.ubi.com/ac_brotherhood/ac_brotherhood_1.01_ww.exe a2b76f16616709cc16537b0e98faa4181ca904ce

    # FIXME: figure out why these executables don't exit, and do a proper workaround or fix
    sleep 10
    if ps augxw | grep -i exe | egrep 'winemenubuilder.exe|setup.exe|PnkBstrA.exe | egrep -v egrep'
    then
        w_warn "Killing processes so patcher does not complain about game still running"
        $WINESERVER -k
        sleep 10
    fi

    w_info "Applying patch $W_CACHE/$W_PACKAGE/ac_brotherhood_1.01_ww.exe..."

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        run ac_brotherhood_1.01_ww.exe
        WinWait, Choose Setup Language, Select
        if ( w_opt_unattended > 0 ) {
            send {Enter}
            winwait, Brotherhood 1.01, License
            WinActivate
            send a         ; Agree
            sleep 500
            send {Enter}   ; Next
            winwait, Brotherhood 1.01, Details
            ControlClick Button1  ; Next
        }
        winwait, Brotherhood 1.01, Complete
        if ( w_opt_unattended > 0 ) {
            send {Enter}
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata atmosphir games \
    title="Atmosphir" \
    publisher="Minor Studios" \
    year="2011" \
    media="manual_download" \
    file1="Atmosphir Installer v1.0.0 fixed.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Minor Studios/Atmosphir/Atmosphir.exe" \
    homepage="http://www.atmosphir.com"

load_atmosphir()
{
    w_download_manual http://download.cnet.com/Atmosphir/3000-7492_4-75335647.html "Atmosphir Installer v1.0.0 fixed.exe" 3ee46b45ea9a8e4a8888148556efb7e61882f7d0
    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        run Atmosphir Installer v1.0.0 fixed.exe
        winwait, Atmosphir Setup, Welcome
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            ControlClick Button2
            winwait, Atmosphir Setup, License Agreement
            sleep 1000
            ControlClick Button2
            winwait, Atmosphir Setup, Choose Install Location
            sleep 1000
            ControlClick Button2
            winwait, Atmosphir Setup, Choose Start Menu Folder
            sleep 1000
            ControlClick Button2
        }
        winwait, Atmosphir Setup, Installation complete
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            send {Space}  ; ControlClick Button4    # start
            sleep 1000
            ControlClick Button2
            ; Let the launcher do the initial full download
            winwait, Atmosphir Launcher
            winwaitclose
            ; then kill the game when it starts
            winwait, Atmosphir
            ;winkill          ; doesn't work, game traps it
            winclose
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata avatar_demo games \
    title="James Camerons Avatar: The Game Demo" \
    publisher="Ubisoft" \
    year="2009" \
    media="manual_download" \
    file1="Avatar_The_Game_Demo.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Ubisoft/Demo/James Cameron's AVATAR - THE GAME (Demo)/bin/AvatarDemo.exe"

load_avatar_demo()
{
    w_download_manual http://www.fileplanet.com/207386/200000/fileinfo/Avatar:-The-Game-Demo Avatar_The_Game_Demo.exe 8d8e4c82312962706bd2620406d592db4f0fa9c1

    if w_workaround_wine_bug 23094 "Installing Visual C++ 2005 runtime to avoid installer crash"
    then
        w_call vcrun2005
    fi

    cd "$W_TMP"
    w_try_unrar "$W_CACHE/$W_PACKAGE/Avatar_The_Game_Demo.exe"
    w_ahk_do "
        SetTitleMatchMode, 2
        SetWinDelay 500
        run, setup.exe
        winwait, Language
        u = $W_OPT_UNATTENDED
        if ( u > 0 ) {
            WinActivate
            controlclick, Button1
            winwait, AVATAR, Welcome
            controlclick, Button1
            winwait, AVATAR, License
            controlclick, Button5
            controlclick, Button2
            winwait, AVATAR, setup type
            controlclick, Button2
        }
        winwait AVATAR
        if ( u > 0 ) {
            ; Strange CRC error workaround. Will check this out. Stay tuned.
            loop
            {
                ifwinexist, CRC Error
                {
                    winactivate, CRC Error
                    controlclick, Button3, CRC Error ; ignore
                }
                ifwinexist, AVATAR, Complete
                {
                    controlclick, Button4
                    break
                }
                sleep 1000
            }
        }
        winwaitclose AVATAR
    "
}

#----------------------------------------------------------------

w_metadata bttf101 games \
    title="Back to the Future Episode 1" \
    publisher="Telltale" \
    year="2011" \
    media="manual_download" \
    file1="bttf_101_setup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Telltale Games/Back to the Future The Game/Episode 1/BackToTheFuture101.exe"

load_bttf101()
{
    w_download_manual http://www.telltalegames.com/bttf bttf_101_setup.exe 9b15e26d9b4d454f714d6559efe509562df9c10b

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        run, bttf_101_setup.exe
        winwait, Back to the Future, Welcome
        if ( w_opt_unattended > 0 ) {
            ControlClick, Button2   ; Next
            winwait, Back to the Future, Checking DirectX
            ControlClick, Button5   ; Don't check
            ControlClick, Button2   ; Next
            winwait, Back to the Future, License
            ControlClick, Button2   ; Agree
            winwait, Back to the Future, Location
            ControlClick, Button2   ; Install
        }
        winwait, Back to the Future, has been installed
        if ( w_opt_unattended > 0 ) {
            ControlClick Button4    ; Don't start now
            ControlClick Button2    ; Finish
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata bioshock_demo games \
    title="Bioshock Demo" \
    publisher="2K Games" \
    year="2007" \
    media="download" \
    file1="nzd_BioShockPC.zip" \
    installed_exe1="$W_PROGRAMS_X86_WIN/2K Games/BioShock Demo/Builds/Release/Bioshock.exe"

load_bioshock_demo()
{
    w_download http://us.download.nvidia.com/downloads/nZone/demos/nzd_BioShockPC.zip 7a19186602cec5210e4505b58965e8c04945b3cf

    w_info "Unzipping demo, installer will start in about 30 seconds."
    w_try unzip "$W_CACHE/$W_PACKAGE/nzd_BioShockPC.zip" -d "$W_TMP/$W_PACKAGE"
    cd "$W_TMP/$W_PACKAGE/BioShock PC Demo"

    w_ahk_do "
        SetTitleMatchMode, 2
        run setup.exe
        winwait, BioShock Demo - InstallShield Wizard, Choose Setup Language
        if ( w_opt_unattended > 0 ) {
            sleep 2000
            ControlClick, Button3
            ControlClick, Button3
            winwait, BioShock Demo - InstallShield Wizard, Welcome
            sleep 1000
            ControlClick, Button1
            winwait, BioShock Demo - InstallShield Wizard, Please read
            sleep 1000
            ControlClick, Button5
            sleep 1000
            ControlClick, Button2
            winwait, BioShock Demo - InstallShield Wizard, Select the setup type
            sleep 1000
            ControlClick, Button2
            winwait, BioShock Demo - InstallShield Wizard, Click Install to begin
            ControlClick, Button1
        }
        winwait, BioShock Demo - InstallShield Wizard, The InstallShield Wizard has successfully installed BioShock
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            ControlClick, Button2     ; don't launch
            ControlClick, Button6     ; don't show readme
            send {Enter}              ; finish
        }
        winwaitclose
        sleep 3000 ; wait for splash screen to close
    "
}

#----------------------------------------------------------------

w_metadata bioshock2 games \
    title="Bioshock 2" \
    publisher="2K Games" \
    year="2010" \
    media="dvd" \
    file1="BIOSHOCK_2.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/2K Games/BioShock 2/SP/Builds/Binaries/Bioshock2Launcher.exe" \
    installed_exe2="$W_PROGRAMS_X86_WIN/2K Games/BioShock 2/MP/Builds/Binaries/Bioshock2Launcher.exe"

load_bioshock2()
{
    w_mount BIOSHOCK_2
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        run ${W_ISO_MOUNT_LETTER}:setup.exe
        if ( w_opt_unattended > 0 ) {
            winwait BioShock 2, Language
            controlclick Button3
            winwait BioShock 2, Welcome
            controlclick Button1 ; Accept
            winwait BioShock 2, License
            controlclick Button3 ; Accept
            sleep 500
            controlclick Button1 ; Next
            winwait BioShock 2, Setup Type
            controlclick Button4 ; Next
            winwait BioShock 2, Ready to Install
            controlclick Button1 ; Install
        }
        winwait BioShock 2, Complete
        if ( w_opt_unattended > 0 ) {
            controlclick Button4 ; Finish
        }
    "
}

#----------------------------------------------------------------

w_metadata bfbc2 games \
    title="Battlefield Bad Company 2" \
    publisher="EA" \
    year="2010" \
    media="dvd" \
    file1="BFBC2.iso"

load_bfbc2()
{
    # Title of installer Window gets the TM symbol wrong, even in UTF-8 locales.
    # Is it like that in Windows, too?
    w_mount BFBC2
    w_read_key
    w_ahk_do "
        SetTitleMatchMode, 2
        run ${W_ISO_MOUNT_LETTER}:setup.exe
        winwait, Bad Company, English
        sleep 500
        ControlClick, Next, Bad Company
        winwait, Bad Company, Registration Code
        sleep 500
        send {RAW}$W_KEY
        ControlClick, Next, Bad Company, Registration Code
        winwait, Bad Company, Setup Wizard will install
        sleep 500
        ControlClick, Button1, Bad Company, Setup Wizard
        winwait, Bad Company, License Agreement
        sleep 500
        ControlClick, Button1, Bad Company, License Agreement
        ControlClick, Button3, Bad Company, License Agreement
        winwait, Bad Company, End-User License Agreement
        sleep 500
        ControlClick, Button1, Bad Company, License Agreement
        ControlClick, Button3, Bad Company, License Agreement
        winwait, Bad Company, Destination Folder
        sleep 500
        ControlClick, Button1, Bad Company, Destination Folder
        winwait, Bad Company, Ready to install
        sleep 500
        ControlClick, Install, Bad Company, Ready to install
        winwait, Authenticate Battlefield
        sleep 500
        ControlClick, Disc authentication, Authenticate Battlefield
        ControlClick, Button4, Authenticate Battlefield
        winwait, Bad Company, PunkBuster
        sleep 500
        ControlClick, Button4, Bad Company, PunkBuster
        ControlClick, Finish, Bad Company
        winwaitclose
    "

    w_warn "Patching to latest version..."

    cd "$W_PROGRAMS_X86_UNIX/Electronic Arts/Battlefield Bad Company 2"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, BFBC2Updater.exe
        winwait, Updater, have to update to
        sleep 500
        ControlClick, Yes, Updater, have to update
        winwait, Updater, successfully updated
        sleep 500
        ControlClick,No, Updater, successfully updated  ; Button2
    "

    if w_workaround_wine_bug 22762
    then
        # FIXME: does this directory name change in Windows 7?
        cd "$W_DRIVE_C/users/$LOGNAME/My Documents"
        if test -f BFBC2/settings.ini
        then
            mv BFBC2/settings.ini BFBC2/oldsettings.ini
            sed 's,DxVersion=auto,DxVersion=9,;
                 s,Fullscreen=true,Fullscreen=false,' BFBC2/oldsettings.ini > BFBC2/settings.ini
        else
            mkdir -p BFBC2
            echo "[Graphics]" > BFBC2/settings.ini
            echo "DxVersion=9" >> BFBC2/settings.ini
        fi
    fi

    if w_workaround_wine_bug 22961
    then
        w_warn 'If the game says "No CD/DVD error", try "sudo mount -o remount,unhide,uid=`uid -u`".  See http://bugs.winehq.org/show_bug.cgi?id=22961 for more info.'
    fi
}

#----------------------------------------------------------------

w_metadata bladekitten_demo games \
    title="Blade Kitten Demo" \
    publisher="Krome Studios" \
    year="2010" \
    media="manual_download" \
    file1="BladeKittenDemoInstall.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Krome Studios/Blade Kitten Demo/BladeKitten_Demo.exe"

load_bladekitten_demo()
{
    w_download_manual http://news.bigdownload.com/2010/09/23/download-blade-kitten-demo BladeKittenDemoInstall.exe d3568f94c1ce284b7381e457e9497065bd45001d

    cp "$W_CACHE/$W_PACKAGE"/BladeKittenDemoInstall.exe "$W_TMP"
    cd "$W_TMP"
    w_ahk_do "
        ; This script always gives full window title, so no need to set a different title match mode
        run BladeKittenDemoInstall.exe
        WinWait Blade Kitten Demo Install Package
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick Button2 ;  Install
            WinWait Blade Kitten Demo, Next
            Sleep 500
            ControlClick Button1
            WinWait Blade Kitten Demo, Cost
            Sleep 500
            ControlClick Button1  ; Next
            WinWait Blade Kitten Demo, ready
            Sleep 500
            ControlClick Button1 ;  Next
            ; Note - in older versions of Wine, the DirectX installer may take 6-10 minutes at this point
        }
        WinWaitClose
        WinWait Blade Kitten Demo, Complete
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick Button1 ;  Close
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata cnc_tiberian_sun games \
    title="Command & Conquer: Tiberian Sun (2010 edition)" \
    publisher="EA" \
    year="1999" \
    media="download" \
    file1="OfficialCnCTiberianSun.rar" \
    installed_exe1="$W_PROGRAMS_X86_WIN\\EA Games\\Command & Conquer The First Decade\\Command & Conquer(tm) Tiberian Sun(tm)\\SUN\\Game.exe"

load_cnc_tiberian_sun()
{
    w_download http://lvlt.bioware.cdn.ea.com/u/f/eagames/cnc3/cnc3tv/Classic/$file1 591aabd639fb9f2d2476a2150f3c00b1162674f5

    cd "$W_PROGRAMS_X86_UNIX"
    # FIXME: we need a progress indicator when unpacking large archives
    w_info "Unpacking rar file.  This will take a minute."
    w_try_unrar "$W_CACHE/$W_PACKAGE/$file1"
}

#----------------------------------------------------------------

w_metadata cnc3_demo games \
    title="Command & Conquer 3 Demo" \
    publisher="EA" \
    year="2007" \
    media="download" \
    file1="CnC3Demo.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Electronic Arts/Command & Conquer 3 Tiberium Wars Demo/CNC3Demo.exe"

load_cnc3_demo()
{
    w_download "http://largedownloads.ea.com/pub/demos/CommandandConquer3/CnC3Demo.exe" f6af21eba2d17eb6d8bb6a131b501b41c3a7eaf7

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, CnC3Demo.exe
        winwait, Conquer 3, free space to install
        if ( w_opt_unattended > 0 ) {
            controlclick, button1
            winwait, WinZip, After installation
            controlclick, button1
            winwait, Conquer 3, InstallShield
            controlclick, button1
            winwait, Conquer 3, license
            controlclick, button3
            controlclick, button5
            winwait, Conquer 3, setup type
            controlclick, button5
            winwait, Conquer 3, EA Link
            controlclick, button1
            winwait, Conquer 3, GameSpy
            controlclick, button1
        }
        winwait, Conquer 3, Launch the program
        if ( w_opt_unattended > 0 )
            controlclick, button1

        winwaitclose, Conquer 3, Launch the program
    "
}

#----------------------------------------------------------------

w_metadata cnc_redalert3_demo games \
    title="Command & Conquer Red Alert 3 Demo" \
    publisher="EA" \
    year="2008" \
    media="manual_download" \
    file1="RedAlert3Demo.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Electronic Arts/Red Alert 3 Demo/RA3Demo.exe"

load_cnc_redalert3_demo()
{
    w_download_manual 'http://www.fileplanet.com/194888/190000/fileinfo/Command-&-Conquer:-Red-Alert-3-Demo' RedAlert3Demo.exe f909b87cc12e386a51be51ede708634348c8af48

    cd "$W_CACHE/$W_PACKAGE"
    if test ! "$W_OPT_UNATTENDED"
    then
        w_try "$WINE" $file1
    else
        w_ahk_do "
            SetWinDelay 1000
            SetTitleMatchMode, 2
            run $file1
            winwait, Demo, readme
            send {enter}                           ; Install button
            winwait, Demo, Agreement
            ControlFocus, TNewCheckListBox1, accept
            send {space}                           ; accept license
            sleep 1000
            send N                                 ; Next
            winwait, Demo, Agreement ; DirectX
            ControlFocus, TNewCheckListBox1, accept
            send {space}                           ; accept license
            sleep 1000
            send N                                 ; Next
            winwait, Demo, Next
            send N                                 ; Next
            winwait, Demo, Install
            send {enter}                           ; Really install
            winwait, Demo, Finish
            send F                                 ; finish
            WinWaitClose
        "
    fi
}

#----------------------------------------------------------------

# http://appdb.winehq.org/objectManager.php?sClass=version&iId=9320
w_metadata blobby_volley games \
    title="Blobby Volley" \
    publisher="Daniel Skoraszewsky" \
    year="2000" \
    media="manual_download" \
    file1="blobby.zip" \
    installed_exe1="c:/BlobbyVolley/volley.exe"

load_blobby_volley()
{
    w_download_manual http://www.chip.de/downloads/Blobby-Volley_12990993.html blobby.zip c7057c77a5009a88d9d877e17a63b5536ebeb177
    w_try_unzip "$W_DRIVE_C/BlobbyVolley" "$W_CACHE/$W_PACKAGE"/blobby.zip
}

#----------------------------------------------------------------

w_metadata cim_demo games \
    title="Cities In Motion Demo" \
    publisher="Paradox Interactive" \
    year="2010" \
    media="manual_download" \
    file1="cim-demo-1-0-8.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Cities In Motion Demo/Cities In Motion.exe"

load_cim_demo()
{
    # 29 Mar 2011 d40408b59bc0e6e33b564e9bbb55dbab6c44c630, Inno Setup installer
    #w_download http://www.pcgamestore.com/games/cities-in-motion-nbsp/trial/cim-demo-1-0-8.exe d40408b59bc0e6e33b564e9bbb55dbab6c44c630
    w_download_manual http://www.fileplanet.com/218762/210000/fileinfo/Cities-in-Motion-Demo cim-demo-1-0-8.exe d40408b59bc0e6e33b564e9bbb55dbab6c44c630
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" cim-demo-1-0-8.exe ${W_OPT_UNATTENDED:+ /sp- /silent /norestart}
}

#----------------------------------------------------------------

w_metadata cod_demo games \
    title="Call of Duty demo" \
    publisher="Activision" \
    year="2003" \
    media="manual_download" \
    file1="call_of_duty_demo.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Call of Duty Single Player Demo/CoDSP.exe"

load_cod_demo()
{
    w_download_manual http://www.gamefront.com/files/968870/call_of_duty_demo_exe Call_Of_Duty_Demo.exe 1c480a1e64a80f7f97fd0acd9582fe190c64ad8e

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run Call_Of_Duty_Demo.exe
        WinWait,Call of Duty Single Player Demo,Welcome
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            ControlClick Button1 ; next
            WinWait,Call of Duty Single Player Demo,License
            sleep 1000
            WinActivate
            send A               ; I Agree
            WinWait,Call of Duty Single Player Demo,System
            sleep 1000
            send n               ; Next
            WinWait,Call of Duty Single Player Demo,Location
            sleep 1000
            send {Enter}
            WinWait,Call of Duty Single Player Demo,Select
            sleep 1000
            send n
            WinWait,Call of Duty Single Player Demo,Start
            sleep 1000
            send i               ; Install
            WinWait,Create Shortcut
            sleep 1000
            send n               ; No
        }
        WinWait,Call of Duty Single Player Demo, Complete
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            send {Enter}         ; Finish
        }
        WinWaitClose
    "

    if w_workaround_wine_bug 21558
    then
        # Work around a buffer overflow - not really Wine's fault
        setvar="@if not defined %__GL_ExtensionStringVersion% then echo \"If you get a buffer overflow error, set __GL_ExtensionStringVersion=17700 before starting Wine.  See http://bugs.winehq.org/show_bug.cgi?id=21558.\""
    else
        setvar=
    fi
}

#----------------------------------------------------------------

w_metadata cod1 games \
    title="Call of Duty" \
    publisher="Activision" \
    year="2003" \
    media="dvd" \
    file1="CoD1.iso" \
    file2="CoD2.iso"

load_cod1()
{
    # FIXME: port load_harder from winetricks and use it when caching first disc
    w_mount CoD1

    w_read_key

    __GL_ExtensionStringVersion=17700 w_ahk_do "
        SetTitleMatchMode, 2
        run ${W_ISO_MOUNT_LETTER}:setup.exe
        WinWait, CD Key, enter
        if ( w_opt_unattended > 0 ) {
            send {Raw}$W_KEY
            ControlClick Button1
            WinWait, CD Key, valid
            ControlClick Button1
            WinWait, Call of Duty, Welcome
            ControlClick Button1
            WinWait, Call of Duty, License
            ControlClick Button3
            WinWait, Call of Duty, Minimum
            ControlClick Button4
            WinWait, Call of Duty, Location
            ControlClick Button1
            WinWait, Call of Duty, Folder
            ControlClick Button1
            WinWait, Call of Duty, Start
            ControlClick Button1
        }
        WinWait, Insert CD, Please insert the Call of Duty CD 2
        "

    "$WINE" eject ${W_ISO_MOUNT_LETTER}:
    w_mount CoD2

    w_ahk_do "
        SetTitleMatchMode, 2
        if ( w_opt_unattended > 0 ) {
            Send {Enter}    ;continue installation
        }
        WinWait, Insert CD, Please insert the Call of Duty CD 1
    "

    "$WINE" eject ${W_ISO_MOUNT_LETTER}:
    w_mount CoD1

    w_ahk_do "
        SetTitleMatchMode, 2
        if ( w_opt_unattended > 0 ) {
            Send {Enter}    ;finalize install
            WinWait, Create Shortcut, Desktop
            ControlClick Button1
            WinWait, DirectX, Call    ;directx 9
            ControlClick Button6
            ControlClick Button1
            WinWait, Confirm DX settings, Are
            ControlClick Button2
        }
        ; handle crash here
        WinWait, Installation Complete, Congratulations!
        if ( w_opt_unattended > 0 ) {
            ControlClick Button1
        }
        WinWaitClose
    "
    "$WINE" eject ${W_ISO_MOUNT_LETTER}:

    if w_workaround_wine_bug 21558
    then
        # Work around a buffer overflow - not really Wine's fault
        setvar="@if not defined %__GL_ExtensionStringVersion% then echo \"If you get a buffer overflow error, set __GL_ExtensionStringVersion=17700 before starting Wine.  See http://bugs.winehq.org/show_bug.cgi?id=21558.\""
    else
        setvar=
    fi
    w_warn "This game is copy-protected, and requires the real disc in a real drive to run."
}

#----------------------------------------------------------------

w_metadata cod4mw_demo games \
    title="Call of Duty 4: Modern Warfare" \
    publisher="Activision" \
    year="2007" \
    media="manual_download" \
    file1="CoD4MWDemoSetup_v2.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Activision/Call of Duty 4 - Modern Warfare Demo/iw3sp.exe"

load_cod4mw_demo()
{
    w_download http://download.cnet.com/Call-of-Duty-4-Modern-Warfare/3000-7441_4-11277584.html CoD4MWDemoSetup_v2.exe 690a5f789a44437ed10784acfdd6418ca4a21886

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, CoD4MWDemoSetup_v2.exe
        WinWait,Modern Warfare,Welcome
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick Button1 ; Next
            WinWait,Modern Warfare, License
            Sleep 500
            ControlClick Button5 ; accept
            Sleep 2000
            ControlClick Button2 ; Next
            WinWait,Modern Warfare, System Requirements
            Sleep 500
            ControlClick Button1 ; Next
            Sleep 500
            ControlClick Button4 ; Next
            WinWait,Modern Warfare, Typical
            Sleep 500
            ControlClick Button4 ; License
            Sleep 500
            ControlClick Button1 ; Next
            WinWait,Question, shortcut
            Sleep 500
            ControlClick Button1 ; Yes
            WinWait,Microsoft DirectX Setup, license
            Sleep 500
            ControlClick Button1 ; Yes
            WinWait,Modern Warfare, finished
            Sleep 500
            ControlClick Button1 ; Finished
        }
        WinWaitClose,WinZip Self-Extractor - CoD4MWDemoSetup_v2
    "
}

#----------------------------------------------------------------

w_metadata cod5_waw games \
    title="Call of Duty 5: World at War" \
    publisher="Activision" \
    year="2008" \
    media="dvd" \
    file1="5330161c7960f0770e6b05f498ab9fd13be4cfad.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Activision/Call of Duty - World at War/CoDWaW.exe"

load_cod5_waw()
{
    w_mount CODWAW

    w_read_key

    w_ahk_do "
        SetTitleMatchMode, 2
        run, ${W_ISO_MOUNT_LETTER}:setup.exe
        winwait, Call of Duty, Key Code
        sleep 1000
        Send $W_KEY
        sleep 1000
        ControlClick, Button1, Call of Duty, Key Code
        winwait, Key Code Check
        sleep 1000
        controlclick, Button1, Key Code Check
        winwait, Call of Duty, License Agreement
        sleep 1000
        controlclick, Button5, Call of Duty, License Agreement
        sleep 1000
        controlclick, Button2, Call of Duty, License Agreement
        ; It wants to install PunkBuster here...OH BOY! Luckily, we can say no (see below)
        winwait, PunkBuster, Anti-Cheat software system
        sleep 1000
        controlclick, Button1, PunkBuster, Anti-Cheat software system
        winwait, Call of Duty, install PunkBuster
        sleep 1000
        ; Punkbuster: both are scripted below, so you can toggle which one you want.
        ; No:
        ; controlclick, Button2, Call of Duty, install PunkBuster
        ; Yes:
        controlclick, Button1, Call of Duty, install PunkBuster
        winwait, PunkBuster, License
        sleep 1000
        controlclick, Button5, PunkBuster, License
        sleep 1000
        controlclick, Button2, PunkBuster, License
        ; /end punkbuster
        winwait, Call of Duty, Minimum System
        sleep 1000
        controlclick, Button1, Call of Duty, Minimum System
        winwait, Call of Duty, Setup Type
        sleep 1000
        controlclick, Button1, Call of Duty, Setup Type
        ; Exits silently after install
        ; Need to wait here else next verb will run before this one is done
        winwaitclose, Call of Duty
    "

    # FIXME: Install latest updates
    w_warn "This game is copy-protected, and requires the real disc in a real drive to run."
}

#----------------------------------------------------------

w_metadata cojbib_demo games \
    title="Call of Juarez: Bound in Blood Demo" \
    publisher="Ubisoft" \
    year="2009" \
    media="manual_download" \
    file1="CoJ2PC_20090713_DEMO_16_buy_now_INSTALLER.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Ubisoft/Demo/Techland/Call of Juarez - Bound in Blood SP Demo/CoJBiBDemo_x86.exe"

load_cojbib_demo()
{
    w_download_manual http://www.gamefront.com/files/14274183/CoJ2PC-20090713-DEMO-16-buy-now-INSTALLER.exe/ CoJ2PC_20090713_DEMO_16_buy_now_INSTALLER.exe 6426101f6c77bacd57c8449b12a3c76db7f761f0

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode 2
        SetWinDelay 500
        run CoJ2PC_20090713_DEMO_16_buy_now_INSTALLER.exe
        winwait Setup, language
        if ( w_opt_unattended > 0 ) {
            controlclick button1 ; next
            winwait Call of Juarez, Welcome
            controlclick button1 ; next
            winwait Call of Juarez, License
            controlclick button2 ; yes
            winwait Call of Juarez, Location
            controlclick button1 ; next
            winwait Call of Juarez, Start
            controlclick button1 ; next
        }
        winwait Call of Juarez, Complete
        if ( w_opt_unattended > 0 )
            controlclick button2 ; next

        winwaitclose Call of Juarez
    "
}

#----------------------------------------------------------------

w_metadata civ4_demo games \
    title="Civilization IV Demo" \
    publisher="Firaxis Games" \
    year="2005" \
    media="manual_download" \
    file1="Civilization4_Demo.zip" \
    installed_file1="$W_PROGRAMS_X86_WIN/Firaxis Games/Sid Meier's Civilization 4 Demo/Civilization4.exe"

load_civ4_demo()
{
    w_download_manual http://download.cnet.com/Civilization-IV-demo/3000-7489_4-10465206.html Civilization4_Demo.zip b54f1e5d0a1c2d1ef456d0c20098c23bbb6a0ea7

    w_try_unzip "$W_TMP" "$W_CACHE/$W_PACKAGE"/Civilization4_Demo.zip
    cd "$W_TMP/$W_PACKAGE"
    chmod +x setup.exe
    w_ahk_do "
        SetTitleMatchMode, 2
        run, setup.exe
        winwait, Choose Setup Language
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            Send {enter}
            winwait, Civilization 4, Welcome
            ControlClick &Next >, Civilization 4
            winwait, Civilization 4, I &accept the terms of the license agreement
            ControlClick I &accept, Civilization 4
            ControlClick &Next >, Civilization 4
            winwait, Civilization 4, Express Install
            ControlClick &Next >, Civilization 4
            winwait, Civilization 4, begin installation
            ControlClick &Install, Civilization 4
            winwait, Civilization 4, InstallShield Wizard Complete
            ControlClick Finish, Civilization 4
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata crayonphysics_demo games \
    title="Crayon Physics Deluxe demo" \
    publisher="Kloonigames" \
    year="2011" \
    media="download" \
    file1="crayon_release52demo.exe" \
    installed_exe1="$W_PROGRAMS_WIN/Crayon Physics Deluxe Demo/crayon.exe" \
    homepage="http://crayonphysics.com"

load_crayonphysics_demo()
{
    w_download http://crayonphysicsdeluxe.s3.amazonaws.com/crayon_release52demo.exe 4ffd64c630f69e7cf024ef946c2c64c8c4ce4eac
    # Inno Setup installer
    w_try "$WINE" "$W_CACHE/$W_PACKAGE/$file1" ${W_OPT_UNATTENDED:+ /sp- /silent /norestart}
}

#----------------------------------------------------------------

w_metadata crysis2 games \
    title="Crysis 2" \
    publisher="EA" \
    year="2011" \
    media="dvd" \
    file1="Crysis2.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/Electronic Arts/Crytek/Crysis 2/bin32/Crysis2.exe"

load_crysis2()
{
    w_mount "Crysis 2"
    w_ahk_do "
        SetTitleMatchMode, 2
        SetWinDelay, 1000
        run ${W_ISO_MOUNT_LETTER}:EASetup.exe
        if ( w_opt_unattended > 0 ) {
            Loop {
                ; On Windows, this window does not pop up
                ifWinExist, Microsoft Visual C++ 2008 Redistributable Setup
                {
                    winwait, Microsoft Visual C++ 2008 Redistributable Setup
                    controlclick, Button12 ; Next
                    winwait, Visual C++, License
                    controlclick, Button11 ; Agree
                    controlclick, Button8 ; Install
                    winwait, Setup, configuring
                    winwaitclose
                    winwait, Visual C++, Complete
                    controlclick, Button2 ; Finish
                    break
                }
                ifWinExist, Setup, Please read the End User
                {
                    break
                }
                sleep 1000
            }
            winwait, Setup, Please read the End User
            controlclick, Button1     ; accept
            sleep 500
            ;controlclick, Button3     ; next
            send {Enter}
            ; Again for DirectX
            winwait, Setup, Please read the following End
            ;controlclick, Button1     ; accept
            send a
            sleep 1000
            ;controlclick, Button3     ; next
            send {Enter}
            winwait,Setup, Ready to install
            controlclick, Button1
        }
        winwait, Setup, Click the Finish button
        if ( w_opt_unattended > 0 ) {
            controlclick, Button5     ; Don't install EA Download Manager
            controlclick, Button1     ; Finish
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata csi6_demo games \
    title="CSI: Fatal Conspiracy Demo" \
    publisher="Ubisoft" \
    year="2010" \
    media="manual_download" \
    file1="CSI6_PC_Demo_05.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Ubisoft/Telltale Games/CSI - Fatal Conspiracy Demo/CSI6Demo.exe"

load_csi6_demo()
{
    w_download_manual http://www.fileplanet.com/217175/download/CSI:-Fatal-Conspiracy-Demo CSI6_PC_Demo_05.exe 28473b4dc9760b659f24a397192b74d170b593bb

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        run, CSI6_PC_Demo_05.exe
        winwait, Installer Language, Please select
        if ( w_opt_unattended > 0 ) {
            ControlClick, Button1   ; Accept default (english)
            ;send {Enter}   ; Accept default (english)
            winwait, CSI - Fatal Conspiracy Demo Setup
            send {Enter}   ; Next
            winwait, CSI - Fatal Conspiracy Demo Setup, License
            send {Enter}   ; Agree
            winwait, CSI - Fatal Conspiracy Demo Setup, Location
            send {Enter}   ; Install
        }
        winwait, CSI - Fatal Conspiracy Demo Setup, Finish
        if ( w_opt_unattended > 0 ) {
            ControlClick Button4
            send {Enter}   ; Finish
            WinWaitClose
        }
    "
}

#----------------------------------------------------------------

w_metadata darknesswithin2_demo games \
    title="Darkness Within 2 Demo" \
    publisher="Zoetrope Interactive" \
    year="2010" \
    media="manual_download" \
    file1="DarknessWithin2Demo.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Iceberg Interactive/Darkness Within 2 Demo/DarkLineage.exe"

load_darknesswithin2_demo()
{
    w_download_manual http://www.bigdownload.com/games/darkness-within-2-the-dark-lineage/pc/darkness-within-2-the-dark-lineage-demo DarknessWithin2Demo.exe

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, DarknessWithin2Demo.exe
        winwait, Darkness Within, will install
        if ( w_opt_unattended > 0 ) {
            ControlClick, TNewButton1
            winwait, Darkness, License
            ControlClick, TNewRadioButton1
            ControlClick, TNewButton2
            winwait, Darkness, Location
            ControlClick, TNewButton3
            winwait, Darkness, shortcuts
            ControlClick, TNewButton4
            winwait, Darkness, additional
            ControlClick, TNewButton4
            winwait, Darkness, Ready to Install
            ControlClick, TNewButton4
            winwait, PhysX, License
            ControlClick, Button3
            ControlClick, Button4
            winwait, PhysX, successfully
            ControlClick, Button1
        }
        winwait, Darkness, Setup has finished
        if ( w_opt_unattended > 0 ) {
            ControlClick, TNewListBoxButton1
            ControlClick, TNewButton4
        }
        winwaitclose, Darkness, Setup has finished
    "

    if w_workaround_wine_bug 23041
    then
        w_call d3dx9_36
    fi
}

#----------------------------------------------------------------

w_metadata darkspore games \
    title="Darkspore" \
    publisher="EA" \
    year="2011" \
    media="dvd" \
    file1="DARKSPORE.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Electronic Arts/Darkspore/DarksporeBin/Darkspore.exe" \
    homepage="http://darkspore.com/"

load_darkspore()
{
    # Mount disc, verify that expected file is present
    w_mount DARKSPORE Darkspore.ico
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        run ${W_ISO_MOUNT_LETTER}:setup.exe
        if ( w_opt_unattended > 0 ) {
            winwait, Choose Setup Language
            controlclick, Button1    ; ok (accept default, English)
            winwait, InstallShield Wizard, Welcome
            controlclick, Button1    ; Next
            winwait, InstallShield Wizard, License Agreement
            controlclick, Button3    ; Accept
            sleep 1000
            controlclick, Button1    ; Next
            winwait, InstallShield Wizard, Select Features
            controlclick, Button5    ; Next
            winwait, InstallShield Wizard, Ready to Install the Program
            controlclick, Button1    ; Install
            winwait, DirectX
            controlclick, Button1    ; Accept
            sleep 1000
            controlclick, Button4    ; Next
            winwait, DirectX, DirectX setup
            controlclick, Button4
            winwait, DirectX, components installed
            controlclick, Button5    ; Finish
        }
        winwait, InstallShield Wizard, You are now ready
        if ( w_opt_unattended > 0 ) {
            controlclick, Button1    ; Uncheck View Readme.txt
            controlclick, Button4    ; Finish
        }
        WinWaitClose, InstallShield Wizard
    "
}

#----------------------------------------------------------------

w_metadata dcuo games \
    title="DC Universe Online" \
    publisher="EA" \
    year="2011" \
    media="dvd" \
    file1="DCUO - Disc 1.iso" \
    file2="DCUO - Disc 2.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Sony Online Entertainment/Installed Games/DC Universe Online Live/LaunchPad.exe"

load_dcuo()
{
    # The installer would take care of this, but let's do it first
    w_call flash

    w_mount "DCUO - Disc 1"
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        run, ${W_ISO_MOUNT_LETTER}:setup.exe
        if ( w_opt_unattended > 0 ) {
            winwait, DC Universe, Anti-virus
            ControlClick, Button1   ; next
            winwait, DC Universe, License
            ControlClick, Button5   ; accept
            sleep 500
            ControlClick, Button2   ; next
            winwait, DC Universe, Shortcut
            ControlClick, Button3   ; next
            Loop
            {
                IfWinExist, DC Universe, not enough space
                {
                    exit 1          ; dang, have to quit
                }
                IfWinExist, DC Universe, Ready
                {
                    break
                }
                Sleep 1000
            }
            winwait, DC Universe, Ready
            ControlClick, Button1   ; next
        }
        winwait, Setup Needs The Next Disk, Please insert disk 2
    "

    w_mount "DCUO - Disc 2"
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        winwait, Setup Needs The Next Disk, Please insert disk 2
        if ( w_opt_unattended > 0 ) {
            ControlClick, Button2   ; next
            winwaitclose
            Loop
            {
                IfWinExist, DirectX, Welcome
                {
                    ControlClick, Button1   ; accept
                    Sleep 1000
                    ControlClick, Button4   ; next
                    WinWait, DirectX, Runtime Install
                    ControlClick, Button4   ; next
                    WinWait, DirectX, Complete
                    ControlClick, Button4   ; next
                    sleep 1000
                    process, close, dxsetup.exe   ; work around strange 'next button does nothing' bug
                }
                IfWinExist, Flash   ; a newer version of flash is already installed
                {
                    ControlClick, Button3   ; quit
                }
                IfWinExist, DC Universe, Complete
                {
                    break
                }
                Sleep 1000
            }
        }
        WinWait, DC Universe, Complete
        if ( w_opt_unattended > 0 ) {
            ControlClick, Button4   ; finish
        }
        winwaitclose
    "
    w_warn "Now let the wookie install itself, and then quit."
}

#----------------------------------------------------------------

w_metadata deadspace games \
    title="Dead Space" \
    publisher="EA" \
    year="2008" \
    media="dvd" \
    file1="DEADSPACE.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Electronic Arts/Dead Space/Dead Space.exe"

load_deadspace()
{
    w_mount DEADSPACE

    if w_workaround_wine_bug 23324
    then
        msvcrun_me_harder="
            winwait, Microsoft
            controlclick, Button1
            "
    else
        msvcrun_me_harder=""
    fi

    w_read_key

    w_ahk_do "
        SetTitleMatchMode, 2
        ; note: if this is the second run, the installer skips the registration code prompt
        run, ${W_ISO_MOUNT_LETTER}:EASetup.exe
        winwait, Dead
        send {Enter}
        winwait, Dead, Registration Code
        send {RAW}$W_KEY
        Sleep 1000
        controlclick, Button2
        $msvcrun_me_harder
        winwait, Setup, License
        Sleep 1000
        controlclick, Button1
        Sleep 1000
        send {Enter}
        winwait, Setup, License
        Sleep 1000
        controlclick, Button1
        Sleep 1000
        send {Enter}
        winwait, Setup, Destination
        Sleep 1000
        controlclick, Button1
        winwait, Setup, begin
        Sleep 1000
        controlclick, Button1
        winwait, Setup, Finish
        Sleep 1000
        controlclick, Button5
        controlclick, Button1
    "
}

#----------------------------------------------------------------

w_metadata deadspace2 games \
    title="Dead Space 2" \
    publisher="EA" \
    year="2011" \
    media="dvd" \
    file1="Disc1.iso" \
    file2="Disc2.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/EA Games/Dead Space 2/deadspace2.exe" \

load_deadspace2()
{
    w_read_key

    w_mount Disc1

    # FIXME: this bug was fixed in 1.3.36, so this is unneccessary
    #
    # Work around bug 25963 (fails to switch discs)
    w_warn "Copying discs to hard drive.  This will take a few minutes."
    cd "$W_TMP"
    # Copy takes a LONG time, so offer a way to avoid copy while debugging verb
    # You'll need to comment out the five "rm -rf"'s, too.
    if test ! -f easetup.exe
    then
        w_try cp -R "$W_ISO_MOUNT_ROOT"/* .
        # Make the directories writable, else 2nd disc copy will fail.
        w_try chmod -R +w .
        w_mount Disc2
        # On Linux, use symlinks for disc 2.  (On Cygwin, we'd have to copy.)
        w_try ln -s "$W_ISO_MOUNT_ROOT"/*.dat .
        mkdir -p movies/en movies/fr
        w_try ln -s "$W_ISO_MOUNT_ROOT"/movies/en/* movies/en/
        w_try ln -s "$W_ISO_MOUNT_ROOT"/movies/fr/* movies/fr/
        # Make the files writable, otherwise you'll get errors when trying to remove the temp directory.
        chmod -R +w .
    fi

    # Install takes a long time, so offer a way to skip installation
    # and go straight to activation while debugging that
    if ! test -f "$W_PROGRAMS_X86_UNIX/EA Games/Dead Space 2/deadspace2.exe"
    then
      w_ahk_do "
        run easetup.exe
        if ( w_opt_unattended > 0 ) {
            SetTitleMatchMode, 2
            ; Not all systems need the Visual C++ runtime
            loop
            {
                ifwinexist, Microsoft Visual C++ 2008 Redistributable Setup
                {
                    sleep 500
                    controlclick, Button12 ; Next
                    winwait, Visual C++, License
                    sleep 500
                    controlclick, Button11 ; Agree
                    sleep 500
                    controlclick, Button8 ; Install
                    winwait, Setup, configuring
                    winwaitclose
                    winwait, Visual C++, Complete
                    sleep 500
                    controlclick, Button2 ; Finish
                    break
                }
                ifwinexist, Setup, Dead Space
                {
                    break
                }
                sleep 1000
            }
            winwait, Setup, License        ; Dead Space license
            sleep 500
            controlclick Button1  ; accept
            controlclick Button3  ; next
            SetTitleMatchMode, slow        ; since word DirectX in next dialog can only be read 'slowly'
            winwait, Setup, DirectX        ; DirectX license
            sleep 500
            controlclick Button1  ; accept
            controlclick Button3  ; next
            winwait, Setup, Ready to install
            sleep 500
            controlclick Button1  ; Install
        }
        winwait, Setup, Completed
        if ( w_opt_unattended > 0 ) {
            controlclick Button5  ; (Don't) install EA Download Manager
            controlclick Button1  ; Finish
        }
        winwaitclose
        "
    fi

    # Activate the game
    cd "$W_PROGRAMS_X86/EA Games/Dead Space 2"
    w_ahk_do "
        run activation.exe
        if ( w_opt_unattended > 0 ) {
            SetTitleMatchMode, 2
            WinWait, Product activation
            sleep 500
            controlclick TBitBtn2  ; Next
            WinWait, Product activation, Serial
            sleep 500
            send $W_KEY
            controlclick TBitBtn3  ; Next
            WinWait, Information
            sleep 4000             ; let user see what happened
            send {Enter}
        }
        WinWaitClose, Product activation
    "
}

#----------------------------------------------------------------

w_metadata deusex2_demo games \
    title="Deus Ex 2 / Deus Ex: Invisible War Demo" \
    publisher="Eidos" \
    year="2003" \
    media="manual_download" \
    file1="dxiw_demo.zip" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Deus Ex - Invisible War Demo/System/DX2.exe"

load_deusex2_demo()
{
    w_download_manual "http://www.techpowerup.com/downloads/1730/Deus_Ex:_Invisible_War_Demo.html" dxiw_demo.zip ccae48fb046d912b3714ea1b4be4294e74bb3092

    w_try unzip "$W_CACHE/$W_PACKAGE/dxiw_demo.zip" -d "$W_TMP"
    cd "$W_TMP"
    w_ahk_do "
        SetTitleMatchMode 2
        SetWinDelay 500
        run setup.exe
        winwait Deus Ex, Launch
        if ( w_opt_unattended > 0 ) {
            controlclick button2
            winwait Deus Ex, Welcome
            controlclick button1
            winwait Deus Ex, License
            controlclick button3 ;accept
            controlclick button1 ;next
            winwait Deus Ex, Setup Type
            controlclick button4
            winwait Deus Ex, Install
            controlclick button1
            winwait Question, Readme
            controlclick button2
            winwait Question, play
            controlclick button2
        }
        winwait Deus Ex, Complete
        if ( w_opt_unattended > 0 )
            controlclick button4
        winwaitclose Deus Ex, Complete
    "
}

#----------------------------------------------------------------

w_metadata diablo2 games \
    title="Diablo II" \
    publisher="Blizzard" \
    year="2000" \
    media="cd" \
    file1="INSTALL.iso" \
    file2="PLAYDISC.iso" \
    file3="CINEMATICS.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Diablo II/Diablo II.exe"

load_diablo2()
{
    w_download http://ftp.blizzard.com/pub/diablo2/patches/PC/D2Patch_113c.exe c78761bfb06999a9788f25a23a1ed30260ffb8ab

    w_read_key

    w_mount INSTALL
    w_ahk_do "
        SetWinDelay 500
        run ${W_ISO_MOUNT_LETTER}:setup.exe
        winwait, Diablo II Setup
        send {i}
        winwait, Choose Installation Size
        send {u}
        send {Enter}
        send {Raw}$LOGNAME
        send {Tab}{Raw}$W_KEY
        send {Enter}
        winwait, Diablo II - choose install directory
        send {Enter}
        winwait, Desktop Shortcut
        send {N}
        winwait, Insert Disc"
    w_mount PLAYDISC
    # Needed by patch 1.13c to avoid disc swapping
    cp "$W_ISO_MOUNT_ROOT"/d2music.mpq "$W_PROGRAMS_UNIX/Diablo II/"
    w_ahk_do "
        send, {Enter}
        Sleep 1000
        winwait, Insert Disc"
    w_mount CINEMATICS
    w_ahk_do "
        send, {Enter}
        Sleep 1000
        winwait, Insert Disc"
    w_mount INSTALL
    w_ahk_do "
        send, {Enter}
        Sleep 1000
        winwait, View ReadMe?
        ControlClick &No, View ReadMe?
        winwait, Register Diablo II Electronically?
        send {N}
        winwait, Diablo II Setup - Video Test
        ControlClick &Cancel, Diablo II Setup - Video Test
        winclose, Diablo II Setup"

    cd "$W_CACHE"/$W_PACKAGE
    w_try "$WINE" D2Patch_113c.exe
    w_ahk_do "
        winwait, Blizzard Updater v2.72, has completed
        Sleep 1000
        send {Enter}
        winwait Diablo II
        Sleep 1000
        ControlClick &Cancel, Diablo II"
    # Dagnabbit, the darn updater starts the game after it updates, no matter what I do?
    w_killall "Game.exe"
}

w_metadata digitanks_demo games \
    title="Digitanks Demo" \
    publisher="Lunar Workshop" \
    year="2011" \
    media="download" \
    file1="digitanks.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Digitanks/digitanksdemo.exe" \
    homepage="http://www.digitanks.com"

load_digitanks_demo()
{
    # 8 june 2011: f204b13dc64c1a54fb1aaf27187c6083ebb16acf
    # 11 Nov 2011: e54ffb07232f434bcfaf7b3d43ddf9affa93ef15
    w_download "http://static.digitanks.com/files/digitanks.exe" e54ffb07232f434bcfaf7b3d43ddf9affa93ef15
    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" $file1 ${W_OPT_UNATTENDED:+ /S}
    if w_workaround_wine_bug 8060 "installing corefonts"
    then
        w_call corefonts
    fi
}

w_metadata dirt2_demo games \
    title="Dirt 2 Demo" \
    publisher="Codemasters" \
    year="2009" \
    media="manual_download" \
    file1="Dirt2Demo.zip" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Codemasters/DiRT2 Demo/dirt2.exe"

load_dirt2_demo()
{
    w_download_manual http://www.joystiq.com/game/dirt-2/download/dirt-2-demo/ Dirt2Demo.zip 13af1beb8c4f6300e4655045b66aea1f8a29f2b3

    w_try_unzip "$W_TMP/$W_PACKAGE" "$W_CACHE/$W_PACKAGE/Dirt2Demo.zip"

    if w_workaround_wine_bug 23532
    then
        w_call gfw
    fi

    if w_workaround_wine_bug 24868
    then
        w_call d3dx9_36
    fi

    cd "$W_TMP/$W_PACKAGE"

    w_ahk_do "
        Run, "Setup.exe"
        WinWait, Choose Setup Language, Select
        if ( w_opt_unattended > 0 ) {
            sleep 500
            ControlClick Button1    ;next
            WinWait, DiRT2 Demo - InstallShield Wizard, Welcome
            sleep 500
            ControlClick Button1    ;next
            WinWait, DiRT2 Demo - InstallShield Wizard, License
            sleep 500
            ControlClick Button3    ;i accept
            sleep 500
            ControlClick Button1    ;next
            WinWait, DiRT2 Demo - InstallShield Wizard, Setup
            sleep 500
            ControlClick Button4    ;next
            WinWait, InstallShield Wizard, In order
            sleep 500
            ControlClick Button1    ;next
            WinWait, DiRT2 Demo - InstallShield Wizard, Ready
            sleep 500
            ControlClick Button1    ;next
        }
        WinWait, DiRT2 Demo - InstallShield Wizard, Complete
        if ( w_opt_unattended > 0 ) {
            sleep 500
            ControlClick Button4    ;finish
        }
        WinWaitClose, DiRT2 Demo - InstallShield Wizard, Complete
        "
}

#----------------------------------------------------------------

w_metadata divinity2_demo games \
    title="Divinity II Demo" \
    publisher="DTP Entertainment" \
    year="2010" \
    media="manual_download" \
    file1="Divinity2_DEMO_EN_US.zip" \
    installed_file1="$W_PROGRAMS_X86_WIN/Divinity II - Ego Draconis - Demo/Bin/Divinity2_Demo.exe"

load_divinity2_demo()
{
    w_download_manual "http://www.gamershell.com/download_54304.shtml" $file1 2a33670b705d4da89e1119d808cda64977bb6096

    w_try unzip -d "$W_TMP" "$W_CACHE/$W_PACKAGE/$file1"
    cd "$W_TMP"

    w_ahk_do "
        Run, Divinity2_DEMO_EN_US.exe
        SetTitleMatchMode, 2
        WinWait,Setup - Divinity II - Ego Draconis - Demo
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick TNewButton1 ; Next
            WinWait,Setup - Divinity II - Ego Draconis - Demo, read
            Sleep 500
            ControlClick TNewRadioButton1 ;agreement
            Sleep 500
            ControlClick TNewButton2 ; Next
            WinWait,Setup - Divinity II - Ego Draconis - Demo, into
            Sleep 500
            ControlClick TNewButton3 ; Next
            WinWait,Setup - Divinity II - Ego Draconis - Demo, place
            Sleep 500
            ControlClick TNewButton4 ; Next
            WinWait,Setup - Divinity II - Ego Draconis - Demo, installation
            Sleep 500
            ControlClick TNewButton4 ; Install
            Loop
            {
                IfWinExist, NVIDIA PhysX Setup, must
                {
                    WinWait,NVIDIA PhysX Setup, must
                    Sleep 500
                    ControlClick Button3 ;accept
                    Sleep 500
                    ControlClick Button4 ; Next
                    WinWait,NVIDIA PhysX Setup, been
                    Sleep 500
                    ControlClick Button1 ; Finish
                }
                IfWinExist,Setup - Divinity II - Ego Draconis - Demo, launched
                {
                    break
                }
                Sleep 2000
            }
            WinWait,Setup - Divinity II - Ego Draconis - Demo, launched
            Sleep 500
            ControlFocus, TNewCheckListBox1, Desktop
            Sleep 500
            Send {Space}
            Sleep 500
            ControlClick TNewButton4 ; Finish
        }
        WinWaitClose
    "

    if w_workaround_wine_bug 24417
    then
        w_call d3dx9_36
    fi
    if w_workaround_wine_bug 25329
    then
        w_call wmp9
    fi
}

#----------------------------------------------------------------

w_metadata demolition_company_demo games \
    title="Demolition Company demo" \
    publisher="Giants Software" \
    year="2010" \
    media="manual_download" \
    file1="DemolitionCompanyDemoENv2.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Demolition Company Demo/DemolitionCompany.exe"

load_demolition_company_demo()
{
    w_download_manual http://www.demolitioncompany-thegame.com/demo.php DemolitionCompanyDemoENv2.exe

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, DemolitionCompanyDemoENv2.exe
        winwait, Setup - Demolition, This will install
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            controlclick, TNewButton1, Setup - Demolition, This will install
            winwait, Setup - Demolition, License Agreement
            sleep 1000
            controlclick, TNewRadioButton1, Setup - Demolition, License Agreement
            sleep 1000
            controlclick, TNewButton2, Setup - Demolition, License Agreement
            winwait, Setup - Demolition, Setup Type
            sleep 1000
            controlclick, TNewButton2, Setup - Demolition, Setup Type
            winwait, Setup - Demolition, Ready to Install
            sleep 1000
            controlclick, TNewButton2, Setup - Demolition, Ready to Install
            winwait, Setup - Demolition, Completing
            sleep 1000
            controlclick, TNewButton2, Setup - Demolition, Completing
        }
        winwaitclose, Setup - Demolition
    "
}

#----------------------------------------------------------------

w_metadata dragonage games \
    title="Dragon Age: Origins" \
    publisher="Bioware / EA" \
    year="2009" \
    media="dvd" \
    file1="DragonAge.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Dragon Age/bin_ship/daorigins.exe"

load_dragonage()
{
    w_read_key

    # game can do this, why do we need to?
    w_call physx

    w_mount DragonAge

    w_ahk_do "
        SetWinDelay 1000
        Run, ${W_ISO_MOUNT_LETTER}:Setup.exe
        SetTitleMatchMode, 2
        winwait, Installer Language
        if ( w_opt_unattended > 0 ) {
            WinActivate
            send {Enter}
            winwait, Dragon Age: Origins Setup
            ControlClick Next, Dragon Age: Origins Setup
            winwait, Dragon Age: Origins Setup, End User License
            ;ControlClick Button4, Dragon Age: Origins Setup  ; agree
            send {Tab}a  ; agree
            ;ControlClick I agree, Dragon Age: Origins Setup
            send {Enter} ; continue
            SetTitleMatchMode, 1
            winwait, Dragon Age: Origins, Registration
            send $W_KEY
            send {Enter}
        }
        winwait, Dragon Age: Origins Setup, Install Type
        if ( w_opt_unattended > 0 )
            send {Enter}
        winwaitclose
    "
    # Since the installer explodes on exit, just wait for the
    # last file it's known to create
    while ! test -f "$W_PROGRAMS_X86_UNIX/Dragon Age/bin_ship/DAOriginsLauncher-MCE.png"
    do
        w_info "Waiting for installer to finish..."
        sleep 1
    done

    # FIXME: does this directory name change in Windows 7?
    ini="$W_DRIVE_C/users/$LOGNAME/My Documents/BioWare/Dragon Age/Settings/DragonAge.ini"
    if ! test -f "$ini"
    then
        w_warn "$ini not found?"
    else
        cp -f "$ini" "$ini.old"
    fi
    if w_workaround_wine_bug 22383 "use strictdrawordering to avoid video problems"
    then
        w_call strictdrawordering=enabled
    fi
    if w_workaround_wine_bug 22557 "Setting UseVSync=0 to avoid black menu"
    then
        sed 's,UseVSync=1,UseVSync=0,' < "$ini" > "$ini.new"
        mv -f "$ini.new" "$ini"
    fi
}

#----------------------------------------------------------------

w_metadata dragonage_ue games \
    title="Dragon Age: Origins - Ultimate Edition" \
    publisher="Bioware / EA" \
    year="2010" \
    media="dvd" \
    file1="DRAGONAGE-1.iso" \
    file2="DRAGONAGE-2.iso"

load_dragonage_ue()
{
    w_read_key

    w_mount DRAGONAGE Setup.exe 1

    # Annoyingly, it runs a web browser so you can activate the extra stuff. Disable that, and w_warn the user after install:
    WINEDLLOVERRIDES="winebrowser.exe="
    export WINEDLLOVERRIDES

    w_ahk_do "
        SetTitleMatchMode, 2
        SetTitleMatchMode, slow
        SetWinDelay 1000
        Run, ${W_ISO_MOUNT_LETTER}:Setup.exe
        winwait, Installer, English
        if ( w_opt_unattended > 0 ) {
            ControlClick Button1, Installer, English
            winwait, Dragon Age: Origins Setup
            ControlClick Button2, Dragon Age: Origins Setup
            winwait, Dragon Age: Origins Setup, License Agreement
            ControlClick Button4, Dragon Age: Origins Setup
            ControlClick Button2, Dragon Age: Origins Setup
            winwait, Dragon Age: Origins, Registration
            controlclick, Edit1
            sleep 1000
            send $W_KEY
            send {Enter}
            winwait, Dragon Age: Origins Setup, Install Type
            controlclick, Button2, Dragon Age: Origins Setup, Install Type
            winwait, Dragon Age: Origins Setup, expanded content
            controlclick, Button1
        }
        winwait, Insert Disc...
    "
    w_mount DRAGONAGE data/ultimate_en.rar 2

    w_ahk_do "
        sleep 5000
        SetTitleMatchMode, 2
        if ( w_opt_unattended > 0 ) {
            controlclick, Button2, Insert Disc...
            winwait, Dragon Age, Setup was completed successfully
            controlclick, Button2, Dragon Age, Setup was completed successfully
        }
        winwait, Dragon Age, Click Finish to close
        if ( w_opt_unattended > 0 ) {
            controlclick, Button5, Dragon Age, Click Finish to close
            controlclick, Button2, Dragon Age, Click Finish to close
        }
        winwaitclose
    "

    if w_workaround_wine_bug 22383
    then
        w_try_winetricks strictdrawordering=enabled
    fi

    if w_workaround_wine_bug 23730
    then
        w_warn "Run with WINEDEBUG=-all to reduce flickering."
    fi

    if w_workaround_wine_bug 23081
    then
        w_warn "If you still see flickering, try applying the patch from http://bugs.winehq.org/show_bug.cgi?id=23081"
    fi

    w_warn "To activate the additional content, visit http://social.bioware.com/redeem_code.php?path=/dragonage/pc/dlcactivate/en"
}

#----------------------------------------------------------------

w_metadata dragonage2_demo games \
    title="Dragon Age II demo" \
    publisher="EA/Bioware" \
    year="2011" \
    media="download" \
    file1="DragonAge2Demo_F93M2qCj_EnEsItPlRu.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Dragon Age 2 Demo/bin_ship/DragonAge2Demo.exe"

load_dragonage2_demo()
{
    w_download http://lvlt.bioware.cdn.ea.com/bioware/u/f/eagames/bioware/dragonage2/demo/DragonAge2Demo_F93M2qCj_EnEsItPlRu.exe a94715cd7943533a3cf1d84d40e667b04e1abc2e

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetWinDelay 500
        SetTitleMatchMode, 2
        run, DragonAge2Demo_F93M2qCj_EnEsItPlRu.exe
        winwait, Installer Language
        if ( w_opt_unattended > 0 ) {
            send {Enter}
            winwait, Dragon Age II Demo Setup
            send {Enter}
            winwait, Dragon Age II Demo Setup, License
            send !a
            send {Enter}
            winwait, Dragon Age II Demo Setup, Select
            send {Enter}
        }
        winwait, Dragon Age II Demo Setup, Complete, completed
        if ( w_opt_unattended > 0 ) {
            send {Enter}
            winwait, Dragon Age II Demo Setup, Completing
            send {Enter}
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata eve games \
    title="EVE Online Tyrannis" \
    publisher="CCP Games" \
    year="2011" \
    media="download" \
    file1="EVE_Online_Installer_561078.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/CCP/EVE/eve.exe"

load_eve()
{
    # http://www.eveonline.com/download/?fallback=1&
    w_download http://content.eveonline.com/561078/EVE_Online_Installer_561078.exe 5b5f0cd4fbd42f82b1d1cccb2e22ddeed97d1d3a

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        run, $file1
        WinWait, EVE Online
        if ( w_opt_unattended > 0 ) {
            WinActivate
            send {Enter}         ; Next
            WinWait, EVE,License Agreement
            WinActivate
            send {Enter}         ; Next
            WinWait, EVE,Choose Install
            WinActivate
            send {Enter}         ; Install
            WinWait, EVE,has been installed
            WinActivate
            ;Send {Tab}{Tab}{Tab} ; select Launch
            ;Send {Space}         ; untick Launch
            ControlClick Button4  ; untick Launch
            Send {Enter}         ; Finish (Button2)
        }
        WinWaitClose, EVE Online
    "
}

#----------------------------------------------------------------

w_metadata fable_tlc games \
    title="Fable: The Lost Chapters" \
    publisher="Microsoft" \
    year="2005" \
    media="cd" \
    file1="FABLE_DISC_1.iso" \
    file2="FABLE DISC 2.iso" \
    file3="FABLE DISC 3.iso" \
    file4="FABLE DISC 4.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft Games/Fable - The Lost Chapters/Fable.exe"

load_fable_tlc()
{
    w_read_key

    if w_workaround_wine_bug 657
    then
        w_call mfc42
    fi

    w_mount FABLE_DISK_1
    w_ahk_do "
        SetTitleMatchMode, 2
        run, ${W_ISO_MOUNT_LETTER}:setup.exe
        WinWait,Fable,Welcome
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick Button1 ; Next
            WinWait,Fable,Please
            Sleep 500
            ControlClick Button4 ; Next
            WinWait,Fable,Product Key
            Sleep 500
            Send $W_KEY
            Send {Enter}
        }
        WinWait,Fable,Disk 2
        "
    w_mount "FABLE DISK 2"
    w_ahk_do "
        SetTitleMatchMode, 2
        WinWait,Fable,Disk 2
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick Button2 ; Retry
        }
        WinWait,Fable,Disk 3
        "

    w_mount "FABLE DISK 3"
    w_ahk_do "
        SetTitleMatchMode, 2
        WinWait,Fable,Disk 3
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick Button2 ; Retry
        }
        WinWait,Fable,Disk 4
        "

    w_mount "FABLE DISK 4"
    w_ahk_do "
        SetTitleMatchMode, 2
        WinWait,Fable,Disk 4
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick Button2 ; Retry
        }
        WinWait,Fable,Disk 1
        WinKill
        "

    # Now tell game what the real disc is so user can insert disc 1 and run the game!
    # FIXME: don't guess it's D:
    cat > "$W_TMP"/$W_PACKAGE.reg <<_EOF_
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\D3BE9C3CAF4226447B48E06CAACF2DDD\InstallProperties]
"InstallSource"="D:\\"

_EOF_
    try_regedit "$W_TMP_WIN"\\$W_PACKAGE.reg

    # Also accept EULA
    cat > "$W_TMP"/$W_PACKAGE.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Microsoft\Microsoft Games\Fable TLC]
"FIRSTRUN"=dword:00000001

_EOF_
    try_regedit "$W_TMP_WIN"\\$W_PACKAGE.reg

    if w_workaround_wine_bug 24912
    then
        # kill off lingering installer
        w_ahk_do "
            SetTitleMatchMode, 2
            WinKill,Fable
        "
        w_killall IDriverT.exe
        w_killall IDriver.exe
    fi

    if w_workaround_wine_bug 25352
    then
        w_call devenum
        w_call quartz
        w_call wmp9
    fi

    if w_workaround_wine_bug 20074
    then
        w_call d3dx9_36
    fi
}

#----------------------------------------------------------------

w_metadata farmsim2011_demo games \
    title="Farming Simulator 2011 Demo" \
    publisher="Astragon" \
    year="2011" \
    media="manual_download" \
    file1="FarmingSimulator2011DemoEN.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Farming Simulator 2011 Demo/game.exe"

load_farmsim2011_demo()
{
    # From http://www.landwirtschafts-simulator.de/demo.php
    w_download_manual http://www.landwirtschafts-simulator.de/demo.php FarmingSimulator2011DemoEN.exe c1221110e55625a3e797a3060c4bf5e3219bf2f0

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetWinDelay 500
        SetTitleMatchMode, 2
        run, FarmingSimulator2011DemoEN.exe
        if ( w_opt_unattended > 0 ) {
            WinWait, Setup - Farming Simulator 2011 Demo
            ControlClick TNewButton1   ; Next
            WinWait, Setup - Farming Simulator 2011 Demo, License Agreement
            ControlClick TNewRadioButton1   ; Accept
            ControlClick TNewButton2   ; Next
            WinWait, Setup - Farming Simulator 2011 Demo, Setup Type
            ControlClick TNewButton2   ; Next
            WinWait, Setup - Farming Simulator 2011 Demo, Ready to Install
            ControlClick TNewButton2   ; Install
        }
        WinWait, Setup - Farming Simulator 2011 Demo, finished
        if ( w_opt_unattended > 0 )
            ControlClick TNewButton2   ; Finish
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata fifa11_demo games \
    title="FIFA 11 Demo" \
    publisher="EA Sports" \
    year="2010" \
    media="download" \
    file1="fifa11_pc_demo_NA.zip" \
    installed_exe1="$W_PROGRAMS_X86_WIN/EA Sports/FIFA 11 Demo/Game/fifa.exe"

load_fifa11_demo()
{
    # From http://www.ea.com/uk/football/news/fifa11-download-2
    w_download "http://static.cdn.ea.com/fifa/u/f/fifa11_pc_demo_NA.zip" c3a66284bffb985f31b11e477dade50c0d4cac52

    w_try unzip -d "$W_TMP" "$W_CACHE/$W_PACKAGE/fifa11_pc_demo_NA.zip"
    cd "$W_TMP"

    w_ahk_do "
        SetTitleMatchMode, 2
        run, EASetup.exe
        winwait, Microsoft Visual C++ 2008, wizard
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            controlclick, Button12, Microsoft Visual C++ 2008, wizard
            winwait, Microsoft Visual C++ 2008, License Terms
            sleep 1000
            controlclick, Button11, Microsoft Visual C++ 2008, License Terms
            sleep 1000
            controlclick, Button8, Microsoft Visual C++ 2008, License Terms
            winwait, Setup, is configuring
            winwaitclose
            winwait, Microsoft Visual C++ 2008, Setup Complete
            sleep 1000
            controlclick, Button2
            ; There are two license agreements...one is for Directx
            winwait, FIFA 11, I &accept the terms in the End User License Agreement
            sleep 1000
            controlclick, Button1
            sleep 1000
            controlclick, Button3
            winwaitclose
            winwait, FIFA 11, I &accept the terms in the End User License Agreement
            sleep 1000
            controlclick, Button1, FIFA 11, I &accept the terms in the End User License Agreement
            sleep 1000
            controlclick, Button3, FIFA 11, I &accept the terms in the End User License Agreement
            winwait, FIFA 11, Ready to install FIFA 11
            sleep 1000
            controlclick, Button1, FIFA 11, Ready to install FIFA 11
        }
        winwait, FIFA 11, Click the Finish button to exit the Setup Wizard.
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            controlclick, Button5, FIFA 11, Click the Finish button to exit the Setup Wizard.
            sleep 1000
            controlclick, Button1, FIFA 11, Click the Finish button to exit the Setup Wizard.
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata hon games \
    title="Heroes of Newerth" \
    publisher="S2 Games" \
    year="2013" \
    media="download" \
    file1="HoNClient-3.1.2.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Heroes of Newerth/hon.exe"

load_hon()
{
    w_download http://dl.heroesofnewerth.com/HoNClient-3.1.2.exe 49123d092f1fa75b8dddc20c817ab8addd5aee5f

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, $file1
        winwait, Installer Language
        if ( w_opt_unattended > 0 ) {
            send {Enter}
            winwait, Heroes of Newerth
            controlclick, Button2, Heroes of Newerth
            winwait, Heroes of Newerth, License
            controlclick, Button2, Heroes of Newerth, License
            winwait, Heroes of Newerth, Components
            controlclick, Button2, Heroes of Newerth, Components
            winwait, Heroes of Newerth, Install Location
            controlclick, Button2, Heroes of Newerth, Install Location
            winwait, Heroes of Newerth, Start Menu
            controlclick, Button2, Heroes of Newerth, Start Menu
            winwait, Heroes of Newerth, Finish
            controlclick, Button2, Heroes of Newerth, Finish
        }
        winwaitclose, Heroes of Newerth, Finish
    "
}

#----------------------------------------------------------------

w_metadata hordesoforcs2_demo games \
    title="Hordes of Orcs 2 Demo" \
    publisher="Freeverse" \
    year="2010" \
    media="manual_download" \
    file1="HoO2Demo.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Hordes of Orcs 2 Demo/HoO2.exe"

load_hordesoforcs2_demo()
{
    w_download_manual http://www.fileplanet.com/216619/download/Hordes-of-Orcs-2-Demo HoO2Demo.exe 1ba26d35697e359f89a30915140e471fadc675da

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        SetWinDelay 500
        SetTitleMatchMode, slow
        run HoO2Demo.exe
        WinWait,Orcs
        if ( w_opt_unattended > 0 ) {
            WinActivate
            ControlFocus, Button1, Hordes ; Next
            sleep 500
            Send n       ; next
            WinWait,Orcs,conditions
            ControlFocus, Button4, Hordes, agree
            Send {Space}
            Send {Enter}  ; next
            WinWait,Orcs,files
            Send {Enter}  ; next
            WinWait,Orcs,exist              ; Destination does not exist, create?
            Send {Enter}  ; yes
            WinWait,Orcs,Start
            Send {Enter}  ; Start
        }
        WinWait,Orcs,successfully
        if ( w_opt_unattended > 0 ) {
            Send {Space}  ; Finish
        }
        winwaitclose Orcs
    "
}

#----------------------------------------------------------------

w_metadata mfsxde games \
    title="Microsoft Flight Simulator X: Deluxe Edition" \
    publisher="Microsoft" \
    year="2006" \
    media="dvd" \
    file1="FSX DISK 1.iso" \
    file2="FSX DISK 2.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft Games/Microsoft Flight Simulator X/fsx.exe"

load_mfsxde()
{
    if w_workaround_wine_bug 25139 "Setting virtual desktop so license screen shows up on first run."
    then
        w_call vd=1024x768
    fi

    w_mount "FSX DISK 1"

    if w_workaround_wine_bug 25558 "Copying disc to hard drive.  This will take a few minutes."
    then
        cd "$W_CACHE/$W_PACKAGE"
        # Copy takes a LONG time, so offer a way to avoid copy while debugging verb
        if test ! -f bothdiscs/setup.exe
        then
            mkdir bothdiscs
            cd bothdiscs
            w_try cp -R "$W_ISO_MOUNT_ROOT"/* .

            # A few files are on both DVDs. Remove them manually so cp doesn't complain.
            rm -f DVDCheck.exe autorun.inf fsx.ico vcredist_x86.exe

            # Make the directories writable, else 2nd disc copy will fail.
            w_try chmod -R +w .

            w_mount "FSX DISK 2"

            # On Linux, use symlinks for disc 2.  (On Cygwin, we'd have to copy.)
            w_try ln -s "$W_ISO_MOUNT_ROOT"/* .

            # Make the files writable, otherwise you'll get errors when trying to remove bothdiscs.
            chmod -R +w .

            # If you leave it mounted, it doesn't ask for the second disk to be inserted.
            # If you mount it without extracting though, the install fails.
            # Apparently it uses the files from the cache, but does a disk check.
        else
            cd bothdiscs
        fi
    else
        w_die "non-broken case not yet supported for this game"
    fi

    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        run setup.exe,,,mfs_pid
        winwait, Microsoft Flight Simulator X, To continue, click Install
        ControlClick, Button1, Microsoft Flight Simulator X, To continue
        ; Accept license:
        winwait, Flight Simulator X - End User License Agreement
        controlclick, Button1, Flight Simulator X - End User License Agreement
        winwait, Microsoft Flight Simulator X Product Activation Wizard
        ; Activate later, currently broken on Wine, see http://bugs.winehq.org/show_bug.cgi?id=25579
        controlclick, Button2, Microsoft Flight Simulator X Product Activation Wizard
        sleep 1000
        controlclick, Button5, Microsoft Flight Simulator X Product Activation Wizard
        ; Close main window:
        winwait, Microsoft Flight Simulator, LEARNING CENTER
        ; A winclose/winkill isn't forceful enough:
        process, close, fsx.exe
        ; Setup doesn't close on its own, because this process doesn't exit cleanly
        process, close, IDriver.exe
    "
}

#----------------------------------------------------------------

w_metadata mfsx_demo games \
    title="Microsoft Flight Simulator X Demo" \
    publisher="Microsoft" \
    year="2006" \
    media="download" \
    file1="FSXDemo.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft Games/Microsoft Flight Simulator X Demo/fsx.exe" \
    wine_showstoppers="26411"

load_mfsx_demo()
{
    w_workaround_wine_bug 26411 "Game hangs on first screen for me"

    if w_workaround_wine_bug 25139 "Setting virtual desktop so license screen shows up on first run"
    then
        w_call vd=1024x768
    fi

    w_download http://download.microsoft.com/download/4/7/7/477dcc35-0b98-42c5-b06f-7ded38a40491/FSXDemo.exe cbb13d2a7918f409f224eab7d3a2014330fc87bc
    cd "$W_TMP"
    unzip "$W_CACHE/$W_PACKAGE"/FSXDemo.exe
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        run setup.exe,,,mfs_pid
        winwait, Microsoft Flight Simulator X, To continue, click Install
        ControlClick, Button1, Microsoft Flight Simulator X, To continue
        ; Accept license:
        winwait, Flight Simulator X - End User License Agreement
        controlclick, Button1, Flight Simulator X - End User License Agreement
        winwait, Microsoft Flight Simulator X Product Activation Wizard
        ; Activate later, currently broken on Wine, see http://bugs.winehq.org/show_bug.cgi?id=25579
        controlclick, Button2, Microsoft Flight Simulator X Product Activation Wizard
        sleep 1000
        controlclick, Button5, Microsoft Flight Simulator X Product Activation Wizard
        ; Close main window:
        winwait, Microsoft Flight Simulator, LEARNING CENTER
        ; A winclose/winkill isn't forceful enough:
        process, close, fsx.exe
        ; Setup doesn't close on its own, because this process doesn't exit cleanly
        process, close, IDriver.exe
    "
}

#----------------------------------------------------------------

w_metadata gothic4_demo games \
    title="Gothic 4 demo (DRM broken on Wine)" \
    publisher="Jowood" \
    year="2010" \
    media="manual_download" \
    file1="ArcaniA_Gothic4_Demo_Setup.zip" \
    installed_exe1="$W_PROGRAMS_X86_WIN/JoWooD Entertainment AG/ArcaniA - Gothic 4 Demo/Arcania.exe"

# http://appdb.winehq.org/objectManager.php?sClass=version&iId=21507

load_gothic4_demo()
{
    w_download_manual http://www.gamershell.com/download_63874.shtml ArcaniA_Gothic4_Demo_Setup.zip d36024c0235878c4589234a56cc8b6e05da5c593

    cd "$W_TMP"
    w_try unzip "$W_CACHE/$W_PACKAGE"/ArcaniA_Gothic4_Demo_Setup.zip

    w_ahk_do "
        Settitlematchmode, 2
        run, ArcaniA_Gothic4_Demo_Setup.exe
        if ( w_opt_unattended > 0 ) {
            winwait, Select Setup Language
            sleep 1000
            controlclick, TNewButton1, Select Setup Language
            winwait, Setup - ArcaniA, Welcome to the
            sleep 1000
            controlclick, TNewButton1, Setup - ArcaniA, Welcome to the
            winwait, Setup - ArcaniA, License Agreement
            sleep 1000
            controlclick, TNewRadioButton1, Setup - ArcaniA, License Agreement
            sleep 1000
            controlclick, TNewButton2, Setup - ArcaniA, License Agreement
            winwait, Setup - ArcaniA, Select Destination Location
            sleep 1000
            controlclick, TNewButton3, Setup - ArcaniA, Select Destination Location
            winwait, Setup - ArcaniA, Select Components
            sleep 1000
            controlclick, TNewButton3, Setup - ArcaniA, Select Components
            winwait, Setup - ArcaniA, Select Start Menu
            sleep 1000
            controlclick, TNewButton4, Setup - ArcaniA, Select Start Menu
            winwait, Setup - ArcaniA, Select Additional
            sleep 1000
            controlclick, TNewButton4, Setup - ArcaniA, Select Additional
            winwait, Setup - ArcaniA, Ready to Install
            sleep 1000
            controlclick, TNewButton4, Setup - ArcaniA, Ready to Install
            winwait, Setup - ArcaniA, Information
            sleep 1000
            controlclick, TNewButton4, Setup - ArcaniA, Information
        }
        winwait, Setup - ArcaniA, Completing
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            ; The two checkboxes share the same button id. App/Wine bug?
            mousemove, 190, 155
            click
            sleep 1000
            mousemove, 190, 180
            click
            sleep 1000
            controlclick, TNewButton4, Setup - ArcaniA, Completing
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata gta_vc games \
    title="Grand Theft Auto: Vice City" \
    publisher="Rockstar" \
    year="2003" \
    media="cd" \
    file1="GTA_VICE_CITY.iso" \
    file2="VICE_CITY_PLAY.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Rockstar Games/Grand Theft Auto Vice City/gta-vc.exe"

load_gta_vc()
{
    w_mount GTA_VICE_CITY
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        Run, ${W_ISO_MOUNT_LETTER}:Setup.exe
        winwait, Choose Setup Language
        if ( w_opt_unattended > 0 ) {
            Send {enter}
            winwait, Grand Theft Auto Vice City, Welcome to the InstallShield Wizard
            Send {enter}
            winwait, Grand Theft Auto Vice City, License Agreement
            Send !a
            send {enter}
            winwait, Grand Theft Auto Vice City, Customer Information
            controlclick, edit1
            send $LOGNAME
            send {tab}
            send company ; installer won't proceed without something here
            send {enter}
            winwait, Grand Theft Auto Vice City, Choose Destination Location
            controlclick, Button1
            winwait, Grand Theft Auto Vice City, Select Components
            controlclick, Button2
            winwait, Grand Theft Auto Vice City, Ready to Install the Program
            send {enter}
        }
        winwait, Setup Needs The Next Disk, Please insert disk 2
    "
    w_mount VICE_CITY_PLAY
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        winwait, Setup Needs The Next Disk, Please insert disk 2
        if ( w_opt_unattended > 0 ) {
            controlclick, Button2
        }
        winwait, Grand Theft Auto Vice City, InstallShield Wizard Complete
        if ( w_opt_unattended > 0 ) {
            send {enter}
        }
        winwaitclose
    "

    if w_workaround_wine_bug 26322 "Setting virtual desktop"
    then
        w_call vd=800x600
    fi

    myexec="Exec=env WINEPREFIX=\"$WINEPREFIX\" wine cmd /c 'C:\\\\\\\\Run-gta_vc.bat'"
    mymenu="$XDG_DATA_HOME/applications/wine/Programs/Rockstar Games/Grand Theft Auto Vice City/Play GTA Vice City.desktop"
    if test -f "$mymenu" && w_workaround_wine_bug 26304 "Fixing system menu"
    then
        # this is a hack, hopefully the wine bug will be fixed soon
        sed -i "s,Exec=.*,$myexec," "$mymenu"
    fi
}

#----------------------------------------------------------------

w_metadata guildwars games \
    title="Guild Wars" \
    publisher="NCsoft" \
    year="2005" \
    media="download" \
    file1="GwSetup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Guild Wars/Gw.exe" \
    homepage="http://www.guildwars.com"

load_guildwars()
{
    w_download "http://guildwars.com/download/" a7c4c8cb3b8cbee20707dcf8176d3da6a1686c05 GwSetup.exe

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        Run, GwSetup.exe
        WinWait, ahk_class ArenaNet_Dialog_Class
        if ( w_opt_unattended > 0 ) {
            ; Wait for network connection to finish.  This might need to be longer.  Can we detect this better?
            Sleep 6000
            ; For some reason, the OK doesn't take for me unless I activate the window first
            WinActivate
            Send {Enter}
            ; Installation takes a long time... and then starts the game, which we don't want.
        }
        WinWait, ahk_class ArenaNet_Dx_Window_Class
        Sleep 4000
        WinClose, ahk_class ArenaNet_Dx_Window_Class
    "
}

#----------------------------------------------------------------

w_metadata hegemonygold_demo games \
    title="Hegemony Gold" \
    publisher="Longbow Games" \
    year="2011" \
    media="download" \
    file1="HegemonyGoldInstaller.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Longbow Digital Arts/Hegemony Gold/Hegemony Gold.exe" \
    homepage="http://www.longbowgames.com/forums/topic/?id=2146" \
    rating="bronze"

load_hegemonygold_demo()
{
    # 6 Mar 2011: 8c4d8aa8f997b106c78b065a4b200e5e1ab846a8
    # 28 Apr 2011: 93677013fc17f014b1640bed070e8bb1b2a17445
    # 25 Jun 2011: 4069656ea3c3760b67d1c5adff37de7472955f72
    # 5 Nov 2011: 723c575ff5fff77941a1c786e28f46c094b8159c
    # 8 Mar 2012: 36634314f571e345d082bdefe1150c76ef5610a7

    w_download "http://www.longbowgames.com/downloads/Hegemony%20Gold%20Installer.exe" 36634314f571e345d082bdefe1150c76ef5610a7 HegemonyGoldInstaller.exe

    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        SetWinDelay 500
        SetTitleMatchMode, 2
        Run, HegemonyGoldInstaller.exe
        WinWait,Hegemony
        if ( w_opt_unattended > 0 ) {
            ControlClick Button2 ; Next
            WinWait,Hegemony, License
            ControlClick Button2 ; Agree
            WinWait,Hegemony, Components
            Click, Left, 187, 185
            Sleep 500
            ControlClick Button2 ; Next
            WinWait,Hegemony, Location
            ControlClick Button2 ; Next
            WinWait,Hegemony, shortcuts
            ControlClick Button2 ; Install
            WinWait,Hegemony, Completing
            ControlFocus,Button4,launch
            Sleep 1000
            Send {Space}
            Sleep 500
            ControlClick Button2 ; finish
        }
        WinWaitClose,Hegemony
    "
}

#----------------------------------------------------------------

w_metadata hegemony_demo games \
    title="Hegemony: Philip of Macedon Demo" \
    publisher="Longbow Games" \
    year="2010" \
    media="download" \
    file1="Hegemony_Philip_of_Macedon_Installer.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Longbow Digital Arts/Hegemony Philip of Macedon/Hegemony Philip of Macedon.exe"

load_hegemony_demo()
{
    # Oct 2010: d3d2aa020d38b594d112360ae40871662d35dea4
    # Nov 2010: 80cad805ad4bed0d3c493f2d9a40d06512c429a9 http://www.longbowgames.com/forums/topic/?id=2223&start=0#post22184
    # Feb 16 2011: 38e92e3e4d0f0d10393790bc37350a2094f60c37
    w_download "http://www.longbowgames.com/downloads/Hegemony%20Philip%20of%20Macedon%20Installer.exe" 38e92e3e4d0f0d10393790bc37350a2094f60c37 Hegemony_Philip_of_Macedon_Installer.exe

    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        SetTitleMatchMode, 2
        run, Hegemony_Philip_of_Macedon_Installer.exe
        winwait, Hegemony, installation
        if ( w_opt_unattended > 0 ) {
            controlclick, Button2
            Sleep 500
            winwait, Hegemony, License
            controlclick, Button2
            winwait, Hegemony, Components
            controlclick, Button2
            winwait, Hegemony, Install Location
            controlclick, Button2
            winwait, Hegemony, shortcuts
            controlclick, Button2
            Loop
            {
                ; Work around wine bug 24484
                IfWinExist, Log message, IKnownFolderManager
                {
                    send {Enter}
                }
                ; Work around wine bug 21261
                IfWinExist, Log message, Games Explorer
                {
                    send {Enter}
                }
                IfWinExist, Hegemony, has been installed
                {
                    break
                }
                Sleep (2000)
            }
            winwait, Hegemony, has been installed
            Sleep 500
            controlclick, Button4
            Sleep 500
            controlclick, Button2
        }
        WinWaitClose,Hegemony
    "
}

#----------------------------------------------------------------

w_metadata hphbp_demo games \
    title="Harry Potter and the Half-Blood Prince Demo" \
    publisher="EA" \
    year="2009" \
    media="download" \
    file1="Release_HBP_demo_PC_DD_DEMO_Final_348428.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Electronic Arts/Harry Potter and the Half-Blood Prince Demo/pc/hp6_demo.exe"

load_hphbp_demo()
{
    case "$LANG" in
    ""|"C") w_die "Harry Potter will not install in the POSIX locale; please do 'export LANG=en_US.UTF-8' or something like that" ;;
    esac

    w_download http://largedownloads.ea.com/pub/demos/HarryPotter/Release_HBP_demo_PC_DD_DEMO_Final_348428.exe dadc1366c3b5e641454aa337ad82bc8c5082bad2

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, Release_HBP_demo_PC_DD_DEMO_FINAL_348428.exe
        winwait, Harry Potter, Install
        if ( w_opt_unattended > 0 ) {
            controlclick, Button1, Harry Potter
            winwait, Setup, License
            controlclick, Button1
            controlclick, Button3
            winwait, Setup, License
            controlclick, Button1
            controlclick, Button3
            winwait, Setup, Destination
            controlclick, Button1
            winwait, Setup, begin
            controlclick, Button1
        }
        winwait, Setup, Finish
        if ( w_opt_unattended > 0 )
            controlclick, Button1
        winwaitclose
    "

    # Work around locale issues by symlinking the app's directory to not have a funny char
    # Won't really work on Cygwin, but that's ok.
    cd "$W_PROGRAMS_X86_UNIX/Electronic Arts"
    ln -s "Harry Potter and the Half-Blood Prince"* "Harry Potter and the Half-Blood Prince Demo"
}

#----------------------------------------------------------------

w_metadata imvu games \
    title="IMVU - Instant Messaging Virtual Universe" \
    publisher="IMVU" \
    year="2004" \
    media="download" \
    file1="InstallIMVU_465.0_st_c.exe" \
    installed_exe1="c:/users/$LOGNAME/Application Data/IMVUClient/IMVUClient.exe"

load_imvu()
{
    w_download http://static-akm.imvu.com/imvufiles/installers/InstallIMVU_465.0_st_c.exe 3a5c6c335227a5709c5772f91d8407edd07d4012

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        SetWinDelay 500
        Run, $file1
        if ( w_opt_unattended > 0 ) {
            WinWait,IMVU Setup, IMVU Extension
            ControlClick Button4 ; Don't install extension
            Sleep 500
            ControlClick Button2 ; Finish
            ; There's no way to tell it not to launch
            WinWait,IMVU Login, chrome
            Click, Left, 29, 230  ; Uncheck [run on startup]
            Sleep 500
            Click, Left, 416, 11  ; Click X on window decoration to close
            Sleep 500
            WinKill,IMVU Login, chrome ; and then close harshly, just in case?
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata kotor1 games \
    title="Star Wars: Knights of the Old Republic" \
    publisher="LucasArts" \
    year="2003" \
    media="cd" \
    file1="KOTOR_1.iso" \
    file2="KOTOR_2.iso" \
    file3="KOTOR_3.iso" \
    file4="KOTOR_4.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/LucasArts/SWKotOR/swkotor.exe"

load_kotor1()
{
    w_mount "KOTOR_1"
    w_ahk_do "
        SetTitleMatchMode 2
        SetWinDelay 500
        run ${W_ISO_MOUNT_LETTER}:setup.exe
        winwait Star Wars, Welcome
        if ( w_opt_unattended > 0 ) {
            controlclick button1
            winwait Star Wars, Licensing Agreement
            controlclick button2
            winwait Question, Licensing Agreement
            controlclick button1
            winwait Star Wars, Destination Folder
            controlclick button1
            winwait Star Wars, Program Folder
            controlclick button2
            winwait Star Wars, Additional Shortcuts
            ;unselect start menu shortcuts
            controlclick button1
            controlclick button2
            controlclick button3
            controlclick button4
            controlclick button5
            controlclick button11
            winwait Star Wars, Review settings
            controlclick button1
        }
        winwait Next Disk, Please insert disk 2
    "
    w_mount "KOTOR_2"
    w_ahk_do "
        SetTitleMatchMode 2
        if ( w_opt_unattended > 0 ) {
            winwait Next Disk
            controlclick button2
        }
        winwait Next Disk, Please insert disk 3
    "
    w_mount "KOTOR_3"
    w_ahk_do "
        SetTitleMatchMode 2
        if ( w_opt_unattended > 0 ) {
            winwait Next Disk
            controlclick button2
        }
        winwait Next Disk, Please insert disk 4
    "
    w_mount "KOTOR_4"
    w_ahk_do "
        SetTitleMatchMode 2
        if ( w_opt_unattended > 0 ) {
            winwait Next Disk
            controlclick button2
            winwait Question, Desktop
            controlclick button2
            winwait Question, DirectX
            controlclick button2 ;don't install directx
        }
        winwait Star Wars, Complete
        if ( w_opt_unattended > 0 ) {
            controlclick button1 ;don't launch game
            controlclick button4
        }
        winwaitclose Star Wars, Complete
    "
}

#----------------------------------------------------------------

w_metadata losthorizon_demo games \
    title="Lost Horizon Demo" \
    publisher="Deep Silver" \
    year="2010" \
    media="manual_download" \
    file1="Lost_Horizon_Demo_EN.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Deep Silver/Lost Horizon Demo/fsasgame.exe"

load_losthorizon_demo()
{
    w_download_manual http://www.fileplanet.com/215704/download/Lost-Horizon-Demo Lost_Horizon_Demo_EN.exe

    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        SetTitleMatchMode, 2
        run Lost_Horizon_Demo_EN.exe
        WinWait,Lost Horizon Demo, Destination
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            Send {RAW}"$W_TMP"
            ControlClick Button2 ;Install
            WinWaitClose,Lost Horizon Demo,Installation
            Sleep 1000
            Click, Left, 169, 371
            WinWait,Lost Horizon Demo - InstallShield Wizard,Welcome
            Sleep 500
            ControlClick Button1 ;Next
            WinWait,Lost Horizon Demo - InstallShield Wizard,License
            ControlFocus,Button3,Lost Horizon Demo
            Sleep 500
            Send {Space}
            ControlClick Button1 ;Next
            WinWait,Lost Horizon Demo - InstallShield Wizard,program
            Sleep 500
            ControlClick Button2 ;Next
            WinWait,Lost Horizon Demo - InstallShield Wizard,features
            Sleep 500
            ControlClick Button4 ;Next
            WinWait,Lost Horizon Demo - InstallShield Wizard,begin
            Sleep 500
            ControlClick Button1 ;Next
        }
        WinWaitClose
        WinWait,Lost Horizon Demo - InstallShield Wizard,Complete
        if ( w_opt_unattended > 0 ) {
            ControlFocus,Button2,Lost Horizon
            Sleep 500
            Send {Space}
            Sleep 500
            ControlClick Button4 ; Finish
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata lego_potc_demo games \
    title="Lego Pirates of the Caribbean Demo" \
    publisher="Travellers Tales" \
    year="2011" \
    media="manual_download" \
    file1="LPOTC_PC_Demo.zip" \
    installed_file1="$W_PROGRAMS_X86_WIN/Disney Interactive Studios/LEGO Pirates DEMO/LEGOPiratesDEMO.exe"

load_lego_potc_demo()
{
    w_download_manual http://www.gamershell.com/download_73976.shtml LPOTC_PC_Demo.zip 3025dcbbee9ff2d74d7837a78ef5b7aceae15d8f
    cd "$W_TMP"
    w_info "Unpacking $file1"
    w_try_unzip . "$W_CACHE/$W_PACKAGE/$file1" LPOTC_PC_Demo.exe
    w_ahk_do "
        SetWinDelay, 500
        SetTitleMatchMode, 2
        SetTitleMatchMode, slow        ; since word English in first dialog can only be read 'slowly'
        run LPOTC_PC_Demo.exe
        if ( w_opt_unattended > 0 ) {
            winwait,LEGO,English
            sleep 500
            winactivate
            send {Tab}{Tab}{Enter}
            winwaitclose,LEGO,English

            winwait, LEGO, License
            winactivate
            send {Space}
            sleep 500
            send {Enter}
            winwaitclose, LEGO, License

            winwait, DirectX
            ControlClick, Button1  ; next
            ;send {Enter}  ; next
            winwaitclose, DirectX

            winwait, LEGO, License       ; DIRECTX shows up in slow text, could wait for that
            winactivate
            sleep 500
            ControlClick, Button1  ; accept
            ;send {Tab}{Tab}{Space} ; accept
            sleep 500
            send {Enter}
            winwaitclose, LEGO, License
        }
        winwait, LEGO, continue
        if ( w_opt_unattended > 0 ) {
            ControlClick, Button2
            sleep 1000
        }
        winwaitclose, LEGO
    "
}

#----------------------------------------------------------------

w_metadata lhp_demo games \
    title="LEGO Harry Potter Demo [Years 1-4]" \
    publisher="Travellers Tales / WB" \
    year="2010" \
    media="download" \
    file1="LEGOHarryPotterDEMO.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/WB Games/LEGO_Harry_Potter_DEMO/LEGOHarryPotterDEMO.exe"

load_lhp_demo()
{
    case "$LANG" in
    *UTF-8*|*utf8*) ;;
    *)
        w_warn "This installer fails in non-utf-8 locales.  Doing 'export LANG=en_US.UTF-8'."
        LANG=en_US.UTF-8
        export LANG
        ;;
    esac

    w_download "http://static.kidswb.com/legoharrypottergame/LEGOHarryPotterDEMO.exe" bb0a30ad9a7cc51c80e1bb1f3eec22e6ccc1a706

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, LEGOHarryPotterDEMO.exe
        winwait, LEGO, language
        if ( w_opt_unattended > 0 ) {
            controlclick, Button1
            winwait, LEGO, License
            controlclick, Button1
            controlclick, Button2
            winwait, LEGO, installation method
            controlclick, Button2
        }
        winwait, LEGO, Finish
        if ( w_opt_unattended > 0 )
            controlclick, Button1

        winwaitclose, LEGO, Finish
    "

    # Work around locale issues by symlinking the app's directory to not have a funny char
    # Won't really work on Cygwin, but that's ok.
    cd "$W_PROGRAMS_X86_UNIX/WB Games"
    ln -s LEGO*Harry\ Potter*DEMO LEGO_Harry_Potter_DEMO
}

#----------------------------------------------------------------

w_metadata lswcs games \
    title="Lego Star Wars Complete Saga" \
    publisher="Lucasarts" \
    year="2009" \
    media="dvd" \
    file1="LEGOSAGA.iso" \
    installed_file1="$W_PROGRAMS_X86_WIN/LucasArts/LEGO Star Wars - The Complete Saga/LEGOStarWarsSaga.exe"

load_lswcs()
{
    w_mount LEGOSAGA
    w_ahk_do "
        run ${W_ISO_MOUNT_LETTER}:setup.exe
        SetTitleMatchMode, 2
        winwait, Choose Setup Language
        if ( w_opt_unattended > 0 ) {
            send {Enter}
            winwait, LEGO, License Agreement
            send a{Enter}
        }
        winwait, LEGO, method
        if ( w_opt_unattended > 0 ) {
            ControlClick Easy Installation
            sleep 1000
        }
        winwaitclose, LEGO
    "
    w_warn "This game is copy-protected, and requires the real disc in a real drive to run."
}

#----------------------------------------------------------------

w_metadata lemonysnicket games \
    title="Lemony Snicket: A Series of Unfortunate Events" \
    publisher="Activision" \
    year="2004" \
    media="cd" \
    file1="Lemony Snicket.iso"

load_lemonysnicket()
{
    w_mount "Lemony Snicket"
    w_ahk_do "
        SetTitleMatchMode, 2
        Run, ${W_ISO_MOUNT_LETTER}:setup.exe
        WinWait, Lemony, Welcome
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            ControlClick, Button1 ; Next
            WinWait, Lemony, License
            sleep 1000
            ControlClick, Button2 ; Accept
            WinWait, Lemony, Minimum System
            sleep 1000
            ControlClick, Button2 ; Yes
            WinWait, Lemony, Destination
            sleep 1000
            ControlClick, Button1 ; Next
            WinWait, Lemony, Select Program Folder
            sleep 1000
            ControlClick, Button2 ; Next
            WinWait, Lemony, Start Copying
            sleep 1000
            ControlClick, Button1 ; Next
            WinWait, Question, Would you like to add a desktop shortcut
            sleep 1000
            ControlClick, Button2 ; No
            WinWait, Question, Would you like to register
            sleep 1000
            ControlClick, Button2 ; No
            ;WinWait, Information, Please register
            ;sleep 1000
            ;ControlClick, Button1 ; OK
            WinWait, Lemony, Complete
            sleep 1000
            ControlClick, Button4 ; Finish
            WinWait, Lemony, Play
            sleep 1000
            ControlClick, Button6 ; Exit
            WinWait, Lemony, Are you sure
            sleep 1000
            ControlClick, Button1 ; Yes already
        }
        WinWaitClose, Lemony
    "
}

#----------------------------------------------------------------

w_metadata luxor_ar games \
    title="Luxor Amun Rising" \
    publisher="MumboJumbo" \
    year="2006" \
    media="cd" \
    file1="LUXOR_AMUNRISING.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/MumboJumbo/Luxor Amun Rising/Luxor AR.exe"

load_luxor_ar()
{
    w_mount LUXOR_AMUNRISING

    w_ahk_do "
        SetWinDelay, 500
        SetTitleMatchMode, 2
        run, ${W_ISO_MOUNT_LETTER}:Luxor_AR_Setup.exe
        winwait, Luxor
        if ( w_opt_unattended > 0 ) {
            ControlClick, Button2   ; Agree
            winwait, Folder
            ControlClick, Button2   ; Install
            winwait, Completed
            ControlClick, Button2   ; Next
        }
        winwait, Success
        if ( w_opt_unattended > 0 ) {
            ControlClick, Button6   ; Uncheck Play
            ControlClick, Button2   ; Close
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata masseffect2 games \
    title="Mass Effect 2 (DRM broken on Wine)" \
    publisher="BioWare" \
    year="2010" \
    media="dvd" \
    file1="MassEffect2.iso" \
    file2="ME2_Disc2.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Mass Effect 2/Binaries/MassEffect2.exe" \
    wine_showstoppers="23184"

load_masseffect2()
{
    w_mount MassEffect2
    w_read_key

    # FIXME: only do this for Nvidia graphics cards
    if w_workaround_wine_bug 23151 "Disabling glsl"
    then
        w_call glsl=disabled
    fi

    w_ahk_do "
        SetTitleMatchMode, 2
        run, ${W_ISO_MOUNT_LETTER}:Setup.exe
        winwait, Installer Language
        if ( w_opt_unattended > 0 ) {
            send {Enter}
            winwait, Mass Effect
            send {Enter}
            winwait, Mass Effect, License
            ControlClick, Button4
            ControlClick, Button2
            winwait, Mass Effect, Registration Code
            send $W_KEY
            ControlClick, Button2
            winwait, Mass Effect, Install Type
            ControlClick, Button2
        }
        winwait, Insert Disc
    "
    sleep 5
    w_mount ME2_Disc2
    w_ahk_do "
        SetTitleMatchMode, 2
        if ( w_opt_unattended > 0 ) {
            winwait, Insert Disc
            ControlClick, Button4
            ; on windows, the first click doesn't seem to do it, so press enter, too
            sleep 1000
            send {Enter}
        }
        ; Some installs may not get to this point due to an installer hang/crash (bug 22919)
        ; The hang/crash happens after the PhysX install but does not seem to affect gameplay
        loop
        {
            ifwinexist, Mass Effect, Finish
            {
                if ( w_opt_unattended > 0 ) {
                    winkill, Mass Effect
                }
                break
            }
            Process, exist, Installer.exe
            me2pid = %ErrorLevel%
            if me2pid = 0
                break
            sleep 1000
        }
    "
}

#----------------------------------------------------------------

w_metadata masseffect2_demo games \
    title="Mass Effect 2" \
    publisher="BioWare" \
    year="2010" \
    media="download" \
    file1="MassEffect2DemoEN.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Mass Effect 2 Demo/Binaries/MassEffect2.exe"

load_masseffect2_demo()
{
    w_download http://static.cdn.ea.com/bioware/u/f/eagames/bioware/masseffect2/ME2_DEMO/MassEffect2DemoEN.exe cda9a25387a98e29772b3ccdcf609f87188285e2

    # FIXME: only do this for Nvidia graphics cards
    if w_workaround_wine_bug 23151 "Disabling glsl"
    then
        w_call glsl=disabled
    fi

    # Don't let self-extractor write into $W_CACHE
    case "$OS" in
        "Windows_NT")
            cp "$W_CACHE/$W_PACKAGE/MassEffect2DemoEN.exe" "$W_TMP"
            chmod +x "$W_TMP"/MassEffect2DemoEN.exe ;;
        *)
            ln -sf "$W_CACHE/$W_PACKAGE/MassEffect2DemoEN.exe" "$W_TMP" ;;
    esac
    cd "$W_TMP"
    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        run, MassEffect2DemoEN.exe
        winwait, Mass Effect 2 Demo
        if ( w_opt_unattended > 0 ) {
            send {Enter}
            winwait, Mass Effect 2 Demo, conflicts
            send {Enter}
            winwait, Mass Effect, License
            ControlClick, Button4
            ;ControlClick, Button2
            send {Enter}
            winwait, Mass Effect, Install Type
            ControlClick, Button2
        }
        ; Some installs may not get to this point due to an installer hang/crash (bug 22919)
        ; The hang/crash happens after the PhysX install but does not seem to affect gameplay
        loop
        {
            ifwinexist, Mass Effect, Finish
            {
                if ( w_opt_unattended > 0 ) {
                    winkill, Mass Effect
                }
                break
            }
            Process, exist, Installer.exe
            me2pid = %ErrorLevel%
            if me2pid = 0
                break
            sleep 1000
        }
    "
}

#----------------------------------------------------------------

w_metadata maxmagicmarker_demo games \
    title="Max & the Magic Marker Demo" \
    publisher="Press Play" \
    year="2010" \
    media="download" \
    file1="max_demo_pc.zip" \
    installed_exe1="$W_PROGRAMS_X86_WIN/maxmagicmarker_demo/max and the magic markerdemo pc.exe"

load_maxmagicmarker_demo()
{
    w_download http://www.maxandthemagicmarker.com/maxdemo/max_demo_pc.zip 1a79c583ff40e7b2cf05d18a89a806fd6b88a5d1

    w_try_unzip "$W_PROGRAMS_X86_UNIX"/$W_PACKAGE "$W_CACHE/$W_PACKAGE"/max_demo_pc.zip
    # Work around bug in game?!
    cd "$W_PROGRAMS_X86_UNIX/$W_PACKAGE"
    mv "max and the magic markerdemo pc" "max and the magic markerdemo pc"_Data
}

#----------------------------------------------------------------

w_metadata mdk games \
    title="MDK (3dfx)" \
    publisher="Playmates International" \
    year="1997" \
    media="cd" \
    file1="MDK.iso" \
    installed_exe1="C:/SHINY/MDK/MDK3DFX.EXE"

load_mdk()
{
    # Needed even on Windows, some people say.  Haven't tried the D3D version on win7 yet.
    w_call glidewrapper

    w_download http://www.falconfly.de/downloads/patch-mdk3dfx.zip edcff0160c62d23b00c55c0bdfa38a6e90d925b0

    w_mount MDK
    cd "$W_ISO_MOUNT_ROOT"
    w_ahk_do "
        SetTitleMatchMode, 2
        SetTitleMatchMode, slow
        run ${W_ISO_MOUNT_LETTER}:setup.exe
        winwait, MDK
        if ( w_opt_unattended > 0 ) {
            click, left, 80, 80   ; USA
            winwait, Welcome, purchasing MDK
            ControlClick, Button1    ; Next
            winwait, Select Target Platform
            ControlClick, Button6    ; Next
            winwait, Select Installation Options
            ControlClick, Button3    ; Large
            ControlClick, Button6    ; Next
            winwait, Destination
            ControlClick, Button1    ; Next
            winwait, Program Folder
            ControlClick, Button2    ; Next
            winwait, Start
            ControlClick, Button1    ; Next
            Loop {
                IfWinExist, Setup, ProgramFolder
                    send {Enter}
                IfWinExist, Setup Complete
                    break
                sleep 500
            }
        }
        WinWait, Setup Complete
        if ( w_opt_unattended > 0 ) {
            ControlClick, Button1  ; uncheck readme
            ControlClick, Button4  ; Finish
            WinWait, Question, DirectX
            ControlClick, Button2  ; No
            WinWait, Information, complete
            ControlClick, Button1  ; No
        }
        WinWaitClose
    "
    cd "$W_DRIVE_C/SHINY/MDK"
    w_try_unzip . "$W_CACHE/$W_PACKAGE"/patch-mdk3dfx.zip

    # TODO: Wine fails to install menu items, add a workaround for that
}

#----------------------------------------------------------------

w_metadata menofwar games \
    title="Men of War" \
    publisher="Aspyr Media" \
    year="2009" \
    media="dvd" \
    file1="Men of War.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Aspyr/Men of War/mow.exe"

load_menofwar()
{
    w_mount "Men of War"

    cd "$W_ISO_MOUNT_ROOT"
    w_ahk_do "
        SetTitleMatchMode, 2
        SetTitleMatchMode, slow
        run ${W_ISO_MOUNT_LETTER}:setup.exe
        winwait, Select Setup Language, Select the language
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            ControlClick, TNewButton1, Select Setup Language, Select the language
            winwait, Men of War
            sleep 1000
            ControlClick, TButton4, Men of War
            winwait, Setup - Men of War, ACCEPTANCE OF AGREEMENT
            sleep 1000
            ControlClick, TNewRadioButton1, Setup - Men of War, ACCEPTANCE OF AGREEMENT
            ControlClick, TNewButton1, Setup - Men of War, ACCEPTANCE OF AGREEMENT
        }
        winwait, Setup - Men of War, Setup has finished installing
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            ControlClick, x242 y254
            ControlClick, x242 y278
            ControlClick, TNewButton1, Setup - Men of War, Setup has finished
        }
    "
}

#----------------------------------------------------------------

w_metadata mb_warband_demo games \
    title="Mount & Blade Warband Demo" \
    publisher="Taleworlds" \
    year="2010" \
    media="download" \
    file1="mb_warband_setup_1143.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Mount&Blade Warband/mb_warband.exe" \
    homepage="http://www.taleworlds.com"

load_mb_warband_demo()
{
    w_download "http://download.taleworlds.com/mb_warband_setup_1143.exe" 94fb829068678e27bcd67d9e0fde7f08c51a23af

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode 2
        run mb_warband_setup_1143.exe
        winwait Warband
        if ( w_opt_unattended > 0 ) {
            controlclick button2
            winwait Warband
            controlclick button2
            winwait Warband, Finish
            controlclick button4
            controlclick button2
        }
        winwaitclose Warband
    "
}

#----------------------------------------------------------------

w_metadata mise games \
    title="Monkey Island: Special Edition" \
    publisher="LucasArts" \
    year="2009" \
    media="dvd" \
    file1="SecretOfMonkeyIslandSE_ddsetup.zip" \
    installed_exe1="$W_PROGRAMS_X86_WIN/LucasArts/The Secret of Monkey Island Special Edition/MISE.exe"

load_mise()
{
    w_download_manual "http://www.direct2drive.com/8241/product/Buy-The-Secret-of-Monkey-Island(R):-Special-Edition-Download" SecretOfMonkeyIslandSE_ddsetup.zip 2e32458698c9ec7ebce94ae5c57531a3fe1dbb9e

    mkdir -p "$W_TMP/$W_PACKAGE"
    cd "$W_TMP/$W_PACKAGE"

    # Don't extract DirectX/dotnet35 installers, they just take up extra time and aren't needed. Luckily, MISE copes well and just skips them if they are missing:
    w_try unzip "$W_CACHE/$W_PACKAGE"/SecretOfMonkeyIslandSE_ddsetup.zip -x DirectX* dotnet*

    w_ahk_do "
        SetTitleMatchMode, 2
        run, setup.exe
        WinWait, The Secret of Monkey Island, This wizard will guide you
        sleep 1000
        ControlClick, Button2
        WinWait, The Secret of Monkey Island, License Agreement
        sleep 1000
        ControlSend, RichEdit20A1, {CTRL}{END}
        sleep 1000
        ControlClick, Button4
        sleep 1000
        ControlClick, Button2
        WinWait, The Secret of Monkey Island, Setup Type
        sleep 1000
        ControlClick, Button2
        WinWait, The Secret of Monkey Island, Click Finish
        sleep 1000
        ControlClick, Button2
        "

    # FIXME: This app has two different keys - you can use either one.  How do we handle that with w_read_key?
    if test -f "$W_CACHE"/$W_PACKAGE/activationcode.txt
    then
        MISE_KEY=`cat "$W_CACHE"/$W_PACKAGE/activationcode.txt`
        w_ahk_do "
            SetTitleMatchMode, 2
            run, $W_PROGRAMS_X86_WIN\\LucasArts\\The Secret of Monkey Island Special Edition\\MISE.exe
            winwait, Product Activation
            ControlClick, Edit1 ; Activation Code
            send $MISE_KEY
            ControlClick Button4 ; Activate Online
            winwait, Product Activation, SUCCESSFUL
            winClose
            sleep 1000
            Process, Close, MISE.exe
        "
    elif test -f "$W_CACHE"/$W_PACKAGE/unlockcode.txt
    then
        MISE_KEY=`cat "$W_CACHE"/$W_PACKAGE/unlockcode.txt`
        w_ahk_do "
            SetTitleMatchMode, 2
            run, $W_PROGRAMS_X86_WIN\\LucasArts\\The Secret of Monkey Island Special Edition\\MISE.exe
            winwait, Product Activation
            ControlClick, Edit3 ; Unlock Code
            send $MISE_KEY
            ControlClick Button6 ; Activate manual
            winClose
            sleep 1000
            Process, Close, MISE.exe
        "
    fi
}

#----------------------------------------------------------------

w_metadata myth2_demo games \
    title="Myth II demo 1.7.2" \
    publisher="Project Magma" \
    year="2011" \
    media="download" \
    file1="Myth2_Demo_172.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Myth II Demo/Myth II Demo.exe" \
    homepage="http://projectmagma.net/"

load_myth2_demo()
{
    # Originally a 1998 game by Bungie; according to Wikipedia, they handed the
    # source code to Project Magma for further development.

    # 1 May 2011 1.7.2 sha1sum e0a8f707377e71314a471a09ad2a55179ea44588
    w_download http://tain.totalcodex.net/items/download/myth-ii-demo-windows e0a8f707377e71314a471a09ad2a55179ea44588 Myth2_Demo_172.exe
    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        SetTitleMatchMode, 2
        SetWinDelay 500
        run, $file1
        winwait, Setup, Welcome
        if ( w_opt_unattended > 0 ) {
            winactivate
            send {Enter} ; next
            winwait, Setup, Components
            send {Enter} ; next
            winwait, Setup, Location
            send {Enter} ; install
        }
        winwait, Setup, Complete
        if ( w_opt_unattended > 0 ) {
            controlclick, Button4   ; Do not run
            controlclick, Button2   ; Finish
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata nfsshift_demo games \
    title="Need for Speed: SHIFT Demo" \
    publisher="EA" \
    year="2009" \
    media="download" \
    file1="NFSSHIFTPCDEMO.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Electronic Arts/Need for Speed SHIFT Demo/shiftdemo.exe"

load_nfsshift_demo()
{
    #w_download http://cdn.needforspeed.com/data/downloads/shift/NFSSHIFTPCDEMO.exe 7b267654d08c54f15813f2917d9d74ec40905db7
    w_download http://www.legendaryreviews.com/download-center/demos/NFSSHIFTPCDEMO.exe 7b267654d08c54f15813f2917d9d74ec40905db7

    w_try cp "$W_CACHE/$W_PACKAGE/$file1" "$W_TMP"

    cd "$W_TMP"
    w_ahk_do "
        SetTitleMatchMode, 2
        SetTitleMatchMode, slow
        run, $file1
        winwait, WinRAR
        if ( w_opt_unattended > 0 ) {
            ControlClick, Button2
            winwait, SHIFT, View the readme
            controlclick, Button1
            ; Not all systems need the Visual C++ runtime
            loop
            {
                ifwinexist, Visual C++
                {
                    controlclick, Button1
                    break
                }
                ifwinexist, Setup, SHIFT Demo License
                {
                    break
                }
                sleep 1000
            }
            winwait, Setup, SHIFT Demo License
            Sleep 1000
            send {Space}
            Sleep 1000
            send {Enter}
            winwait, Setup, DirectX
            Sleep 1000
            send {Space}
            Sleep 1000
            send {Enter}
            winwait, Setup, Destination
            Sleep 1000
            send {Enter}
            winwait, Setup, begin
            Sleep 1000
            controlclick, Button1
        }
        winwait, Setup, Finish
        if ( w_opt_unattended > 0 ) {
            Sleep 1000
            controlclick, Button5
            controlclick, Button1
        }
        winwaitclose, Setup, Finish
    "
}

#----------------------------------------------------------------

w_metadata njcwp_trial apps \
    title="NJStar Chinese Word Processor trial" \
    publisher="NJStar" \
    year="2009" \
    media="download" \
    file1="njcwp.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/NJStar Chinese WP/njstar.exe" \
    homepage="http://www.njstar.com/cms/njstar-chinese-word-processor"

load_njcwp_trial()
{
    w_download http://www.njstar.com/download/njcwp.exe 006da155bad1ac4a73b953c98cb821eb7fd96507
    cd "$W_CACHE/$W_PACKAGE"
    if test "$W_OPT_UNATTENDED"
    then
        w_ahk_do "
        SetTitleMatchMode, 2
        run $file1
        WinWait, Setup, Wizard
        ControlClick Button2 ; next
        WinWait, Setup, License
        ControlClick Button2 ; agree
        WinWait, Setup, Install
        ControlClick Button2 ; install
        WinWait, Setup, Completing
        ControlClick Button4 ; do not launch
        ControlClick Button2 ; finish
        WinWaitClose
        "
    else
        w_try "$WINE" $file1
    fi
}

#----------------------------------------------------------------

w_metadata njjwp_trial apps \
    title="NJStar Japanese Word Processor trial" \
    publisher="NJStar" \
    year="2009" \
    media="download" \
    file1="njjwp.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/NJStar Japanese WP/njstarj.exe" \
    homepage="http://www.njstar.com/cms/njstar-japanese-word-processor"

load_njjwp_trial()
{
    w_download http://www.njstar.com/download/njjwp.exe 363d22e4ca7b79d0290a8ccdb0fa99169971d418
    cd "$W_CACHE/$W_PACKAGE"
    if test "$W_OPT_UNATTENDED"
    then
        w_ahk_do "
        SetTitleMatchMode, 2
        run $file1
        WinWait, Setup, Wizard
        ControlClick Button2 ; next
        WinWait, Setup, License
        ControlClick Button2 ; agree
        WinWait, Setup, Install
        ControlClick Button2 ; install
        WinWait, Setup, Completing
        ControlClick Button4 ; do not launch
        ControlClick Button2 ; finish
        WinWaitClose
        "
    else
        w_try "$WINE" $file1
    fi
}

#----------------------------------------------------------------

w_metadata oblivion games \
    title="Elder Scrolls: Oblivion" \
    publisher="Bethesda Game Studios" \
    year="2006" \
    media="dvd" \
    file1="Oblivion.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Bethesda Softworks/Oblivion/Oblivion.exe"

load_oblivion()
{
    w_mount "Oblivion"

    cd "$W_ISO_MOUNT_ROOT"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, Setup.exe
        winwait, Oblivion, Welcome to the
        if ( w_opt_unattended > 0 ) {
            sleep 500
            controlclick, Button1
            winwait, Oblivion, License Agreement
            sleep 500
            controlclick, Button3
            sleep 500
            controlclick, Button1
            winwait, Oblivion, Choose Destination
            sleep 500
            controlclick, Button1
            winwait, Oblivion, Ready to Install
            sleep 500
            controlclick, Button1
            winwait, Oblivion, Complete
            sleep 500
            controlclick, Button1
            sleep 500
            controlclick, Button2
            sleep 500
            controlclick, Button3
        }
        winwaitclose, Oblivion, Complete
    "

    if w_workaround_wine_bug 20074 "Installing native d3dx9_36"
    then
        w_call d3dx9_36
    fi
}

#----------------------------------------------------------------

w_metadata penpenxmas games \
    title="Pen-Pen Xmas Olympics" \
    publisher="Army of Trolls / Black Cat" \
    year="2007" \
    media="download" \
    file1="PenPenXmasOlympics100.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/PPO/PPO.exe"

load_penpenxmas()
{
    W_BROWSERAGENT=1 \
    w_download http://retrospec.sgn.net/download/files/PenPenXmasOlympics100.exe 36ec83cffa0ad3cc19dea33193b54bdaaea6db5b

    cd "$W_CACHE/$W_PACKAGE"
    "$WINE" PenPenXmasOlympics100.exe $W_UNATTENDED_SLASH_S
}

#----------------------------------------------------------------

w_metadata plantsvszombies games \
    title="Plants vs. Zombies" \
    publisher="PopCap Games" \
    year="2009" \
    media="download" \
    file1="PlantsVsZombiesSetup.exe" \
    installed_file1="$W_PROGRAMS_X86_WIN/PopCap Games/Plants vs. Zombies/PlantsVsZombies.exe"

load_plantsvszombies()
{
    w_download "http://downloads.popcap.com/www/popcap_downloads/PlantsVsZombiesSetup.exe" c46979be135ef1c486144fa062466cdc51b740f5

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        run PlantsVsZombiesSetup.exe
        winwait, Plants vs. Zombies Installer
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            send {Enter}
            winwait, Plants vs. Zombies License Agreement
            ControlClick Button1
        }
        winwait, Plants vs. Zombies Installation Complete!
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            send {Space}{Enter}
            ControlClick, x309 y278, Plants vs. Zombies Installation Complete!,,,, Pos
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata popfs games \
    title="Prince of Persia: The Forgotten Sands" \
    publisher="Ubisoft" \
    year="2010" \
    media="dvd" \
    file1="PoP_TFS.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Ubisoft/Prince of Persia The Forgotten Sands/Prince of Persia.exe"

load_popfs()
{
    w_mount PoP_TFS

    w_ahk_do "
        SetTitleMatchMode, 2
        run, ${W_ISO_MOUNT_LETTER}:Setup.exe
        winwait, Prince of Persia, Language
        if ( w_opt_unattended > 0 ) {
            sleep 500
            ControlClick, Button3
            winwait, Prince of Persia, Welcome
            sleep 500
            ControlClick, Button1
            winwait, Prince of Persia, License
            sleep 500
            ControlClick, Button5
            sleep 500
            ControlClick, Button2
            winwait, Prince of Persia, Click Install
            sleep 500
            ControlClick, Button1
            ; Avoid error when creating desktop shortcut
            Loop
            {
                IfWinActive, Prince of Persia, Click Finish
                    break
                IfWinExist, Prince of Persia, desktop shortcut
                {
                sleep 500
                    ControlClick, Button1, Prince of Persia, desktop shortcut
                    break
                }
                sleep 5000
            }
        }
        winwait, Prince of Persia, Click Finish
        if ( w_opt_unattended > 0 ) {
            sleep 500
            ControlClick, Button4
        }
    "
}

#----------------------------------------------------------------

w_metadata qq apps \
 title="QQ 8.0 (Chinese chat app)" \
 publisher="Tencent" \
 year="2015" \
 media="download" \
 file1="QQ8.0.exe" \
 file2="QQ.tar.gz"\
 installed_exe1="$W_PROGRAMS_X86_WIN/Tencent/QQ/Bin/QQScLauncher.exe" \
 homepage="http://www.qq.com" \
 unattended="no"

load_qq()
{
    w_download http://dldir1.qq.com/qqfile/qq/QQ8.0/16968/QQ8.0.exe ef92f3863113971c95a79aa75e601893d803826c
    w_download http://hillwoodhome.net/wine/QQ.tar.gz 08de45d3e5bb34b22e7c33e1163daec69742db58

    if w_workaround_wine_bug 5162 "Installing native riched20 to work around can't input username."
    then
        w_call riched20
    fi

    # Make sure chinese fonts are available
    w_call fakechinese

    # uses mfc42u.dll
    w_call mfc42

    if w_workaround_wine_bug 38171 "Installing desktop file to work around bug"
    then
        cd "$W_TMP/"
        tar -zxf "$W_CACHE/qq/QQ.tar.gz"
        mkdir -p $HOME/.local/share/applications/wine/Programs/腾讯软件/QQ
        mkdir -p $HOME/.local/share/icons/hicolor/48x48/apps
        mkdir -p $HOME/.local/share/icons/hicolor/256x256/apps
        w_try mv QQ/腾讯QQ.desktop ~/.local/share/applications/wine/Programs/腾讯软件/QQ
        w_try mv QQ/48x48/QQ.png ~/.local/share/icons/hicolor/48x48/apps
        w_try mv QQ/256x256/QQ.png ~/.local/share/icons/hicolor/256x256/apps
        echo Exec=env WINEPREFIX="$WINEPREFIX" "$WINE" $W_PROGRAMS_X86_WIN\/Tencent\/QQ\/bin\/QQScLauncher.exe >> $HOME/.local/share/applications/wine/Programs/腾讯软件/QQ/腾讯QQ.desktop
    fi

    if w_workaround_wine_bug 39657 "Disable ntoskrnl.exe to work around can't be started bug"
    then
        w_override_dlls disabled ntoskrnl.exe
    fi

    if w_workaround_wine_bug 37680 "Disable txplatform.exe to work around QQ can't be quit cleanly"
    then
        w_override_dlls disabled txplatform.exe
    fi

    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" "$file1"
}

#----------------------------------------------------------------

w_metadata qqintl apps \
    title="QQ International Instant Messenger 2.11" \
    publisher="Tencent" \
    year="2014" \
    media="download" \
    file1="QQIntl2.11.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Tencent/QQIntl/Bin/QQ.exe" \
    homepage="http://www.imqq.com" \
    unattended="no"

load_qqintl()
{
    w_download http://dldir1.qq.com/qqfile/QQIntl/QQi_PC/QQIntl2.11.exe 030df82390e7962177fcef66fc1a0fd1a3ba4090

    if w_workaround_wine_bug 33086 "Installing native riched20 to allow typing in username"
    then
        w_call riched20
    fi

    if w_workaround_wine_bug 37617 "Installing native wininet to work around crash"
    then
        w_call wininet
    fi

    if w_workaround_wine_bug 37680 "Disable txplatform.exe to work around QQ can't be quit cleanly"
    then
        w_override_dlls disabled txplatform.exe
    fi

    # Make sure chinese fonts are available
    w_call fakechinese

    # wants mfc80u.dll
    w_call vcrun2005

    cd "$W_CACHE/$W_PACKAGE"
    w_try "$WINE" "$file1"
}

#----------------------------------------------------------------

w_metadata ragnarok games \
    title="Ragnarok" \
    publisher="GRAVITY" \
    year="2002" \
    media="manual_download" \
    file1="iRO-13.2.2-FullInstall-20110421-1717.msi" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Gravity/Ragnarok Online/Ragnarok.exe"

load_ragnarok()
{
    if w_workaround_wine_bug 657 "Visual C++ 6 runtime"
    then
        w_call vcrun6
    fi

    # publisher puts SHA1 checksums on download page, nice
    # BDA295E3A2A57CD02BD122ED7BF4836AC012369A
    w_download_manual http://www.playragnarok.com/downloads/clientdownload.aspx iRO-13.2.2-FullInstall-20110421-1717.msi bda295e3a2a57cd02bd122ed7bf4836ac012369a

    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        Run, msiexec /i $file1
        SetTitleMatchMode, 2
        WinWait, Ragnarok Online Setup, Please read the Ragnarok Online License Agreement
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick Button1
            Sleep 500
            ControlClick Button3
            }
            WinWait, Ragnarok Online Setup, Completed the Ragnarok Online Setup Wizard
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick Button1 ;Direct
        }
    "

    # Game autoupdates:
    w_killall "Ragnarok.exe"
}

#----------------------------------------------------------------

w_metadata rct3deluxe games \
    title="RollerCoaster Tycoon 3 Deluxe (DRM broken on Wine)" \
    publisher="Atari" \
    year="2004" \
    media="cd" \
    file1="RCT3.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Atari/RollerCoaster Tycoon 3/RCT3.EXE"\
    wine_showstoppers="21448"

load_rct3deluxe()
{
    w_mount RCT3

    # FIXME: make videos and music work
    # Game still doesn't show .wmv logo videos nor play .wma background audio in menu
    # though it does in Jake's screencast.  Loading wmp9 and devenum gets it to
    # try to load the .wmv logos, but it crashes in quartz :-(
    # But at least it's playable without the logo videos and background.

    w_ahk_do "
        SetWinDelay 500
        SetTitleMatchMode, 2
        run ${W_ISO_MOUNT_LETTER}:setup-rtc3.exe
        if ( w_opt_unattended > 0 ) {
            WinWait, Select Setup Language
            controlclick, TButton1   ; accept
            WinWait Setup - RollerCoaster Tycoon 3, Welcome
            controlclick, TButton1   ; Next
            WinWait Setup - RollerCoaster Tycoon 3, License
            controlclick, TRadioButton1   ; Accept
            sleep 500
            controlclick, TButton2   ; Next
            WinWait Setup - RollerCoaster Tycoon 3, Destination
            controlclick, TButton3   ; Next
            WinWait Setup - RollerCoaster Tycoon 3, Start Menu
            controlclick, TButton4   ; Next
            WinWait Setup - RollerCoaster Tycoon 3, Additional
            controlclick, TButton4   ; Next
            WinWait Setup - RollerCoaster Tycoon 3, begin
            controlclick, TButton4   ; Install
            WinWait, Atari Product Registration
            controlclick, Button6   ; Close
            WinWait, Product Registration, skip
            controlclick, Button2   ; Yes, skip
        }
        WinWait Setup - RollerCoaster Tycoon 3, finished
        if ( w_opt_unattended > 0 ) {
            controlclick, TNewCheckListBox1   ; uncheck Launch
            controlclick, TButton4   ; Finish
        }
        WinWaitClose Setup - RollerCoaster Tycoon 3, finished
        "
}

#----------------------------------------------------------------

w_metadata rayman2_demo games \
    title="Rayman 2 High Demo" \
    publisher="Ubisoft" \
    year="1999" \
    media="download" \
    file1="rayman2high.zip" \
    installed_exe1="c:/UbiSoft/Rayman2Demo/Rayman2Demo.exe"

load_rayman2_demo()
{
    w_download "ftp://ftp.ubisoft.com/Rayman2/rayman2high.zip" 14b2ad6f41e2e1358f3a4a5167d67a7111ea4fb5

    cd "$W_TMP"
    w_try unzip "$W_CACHE/$W_PACKAGE/rayman2high.zip"

    w_ahk_do "
        SetWinDelay 500
        SetTitleMatchMode, 3
        Run, SETUP.EXE
        WinWaitActive, UBI Soft Installer - Language Choice
        if ( w_opt_unattended > 0 ) {
            ControlClick button1 ; OK
            WinWait, Ubi Soft Installer - Rayman 2 Demo
            ControlClick button1 ; Install
            WinWait, Ubi Soft Installer - Configuration choice
            ControlClick button1 ; Install
            WinWait, Ubi Soft Installer - Installation Directory
            ControlClick button1 ; OK
            WinWait, Ubi Soft Installer - Shortcut Choice
            ControlClick button1 ; OK
            WinWait, Ubi Soft Installer - Information file
            ControlClick button2 ; No
        }
        WinWait, Ubi Soft Installer - Rayman 2 Demo
        if ( w_opt_unattended > 0 ) {
            ControlClick button4 ; Quit
        }
        WinWaitClose
    "

    myexec="Exec=env WINEPREFIX=\"$WINEPREFIX\" wine "'C:\\\\\\\\windows\\\\\\\\UbiSoft\\\\\\\\SetupUbi.exe -play Rayman2'
    mymenu="$HOME/Desktop/To Play Rayman 2 Demo.desktop"
    if test -f "$mymenu" && w_workaround_wine_bug 26303 "Fixing desktop entry"
    then
        # this is a hack, hopefully the wine bug will be fixed soon
        sed -i "s,Exec=.*,$myexec," "$mymenu"
    fi
    mymenu="$XDG_DATA_HOME/applications/wine/Programs/Ubi Soft Games/Rayman 2 Demo/1 To Play Rayman 2 Demo.desktop"
    if test -f "$mymenu" && w_workaround_wine_bug 26304 "Fixing system menu"
    then
        # this is a hack, hopefully the wine bug will be fixed soon
        sed -i "s,Exec=.*,$myexec," "$mymenu"
    fi
}

#----------------------------------------------------------------

w_metadata riseofnations_demo games \
    title="Rise of Nations Trial" \
    publisher="Microsoft" \
    year="2003" \
    media="manual_download" \
    file1="RiseOfNationsTrial.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft Games/Rise of Nations Trial/nations.exe"

load_riseofnations_demo()
{
    w_download_manual http://download.cnet.com/Rise-of-Nations-Trial-Version/3000-7562_4-10730812.html RiseOfNationsTrial.exe 33cbf1ebc0a93cb840f6296d8b529f6155db95ee

    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        SetTitleMatchMode, 2
        run RiseOfNationsTrial.exe
        WinWait,Rise Of Nations Trial Setup
        if ( w_opt_unattended > 0 ) {
            sleep 2500
            ControlClick CButtonClassName2
            WinWait,Rise Of Nations Trial Setup, installed
            sleep 2500
            ControlClick CButtonClassName7
        }
        WinWaitClose
    "

    if w_workaround_wine_bug 9027
    then
        w_call directmusic
    fi
}

#----------------------------------------------------------------

w_metadata secondlife games \
    title="Second Life Viewer" \
    publisher="Linden Labs" \
    year="2003-2011" \
    media="download" \
    file1="Second_Life_3-2-8-248931_Setup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/SecondLifeViewer/SecondLife.exe"

load_secondlife()
{
    w_download http://download.cloud.secondlife.com/Viewer-3/Second_Life_3-2-8-248931_Setup.exe e08c16edc4d2fb68bb6275bed11a259a74918da5

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        SetWinDelay 500
        run, $file1
        if ( w_opt_unattended > 0 ) {
            winwait, Installer Language
            send {Enter}
            winwait, Installation Folder
            send {Enter}
        }
        winwait, Second Life, Start Second Life now
        if ( w_opt_unattended > 0 ) {
            send {Tab}{Enter}
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata sims3 games \
    title="The Sims 3 (DRM broken on Wine)" \
    publisher="EA" \
    year="2009" \
    media="dvd" \
    file1="Sims3.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Electronic Arts/The Sims 3/Game/Bin/TS3.exe" \
    wine_showstoppers="26273"

load_sims3()
{
    w_read_key

    w_mount Sims3
    # Default lang, USA, accept defaults, uncheck EA dl mgr, uncheck readme
    w_ahk_do "
        run ${W_ISO_MOUNT_LETTER}:Sims3Setup.exe
        winwait, Choose Setup Language
        if ( w_opt_unattended > 0 ) {
            send {Enter}
            SetTitleMatchMode, 2
            winwait, - InstallShield Wizard
            sleep 1000
            ControlClick &Next >, - InstallShield Wizard
            sleep 1000
            send uuuuuu{Tab}{Tab}{Enter}
            sleep 1000
            send a{Enter}
            sleep 1000
            send {Raw}$W_KEY
            send {Enter}
            winwait, - InstallShield Wizard, Setup Type
            send {Enter}
            winwait, - InstallShield Wizard, Click Install to begin
            send {Enter}
            winwait, - InstallShield Wizard, EA Download Manager
            ControlClick Yes, - InstallShield Wizard
            send {Enter}
        }
        winwait, - InstallShield Wizard, Complete
        if ( w_opt_unattended > 0 ) {
            ControlClick View the readme file, - InstallShield Wizard
            ControlClick Finish, - InstallShield Wizard
        }
        winwaitclose
    "
    w_umount

    # DVD region code is last digit.
    # FIXME: download appropriate one rather than just US version.
    w_download http://akamai.cdn.ea.com/eadownloads/u/f/sims/sims3/patches/TS3_1.19.44.010001_Update.exe 7d21a81aaea70bf102267456df4629ce68be0cc8

    cd "$W_CACHE"/$W_PACKAGE
    w_ahk_do "
        run TS3_1.19.44.010001_Update.exe
        SetTitleMatchMode, 2
        winwait, - InstallShield Wizard, Complete
        if ( w_opt_unattended > 0 ) {
            ControlClick Finish, - InstallShield Wizard
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata simsmed games \
    title="The Sims Medieval (DRM broken on Wine)" \
    publisher="EA" \
    year="2011" \
    media="dvd" \
    file1="TSimsM.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Electronic Arts/The Sims Medieval/Game/Bin/TSM.exe" \
    wine_showstoppers="26273"

load_simsmed()
{
    w_read_key

    w_mount TSimsM
    # Default lang, USA, accept defaults, uncheck EA dl mgr, uncheck readme
    w_ahk_do "
        SetTitleMatchMode, 2
        SetWinDelay 1000
        run ${W_ISO_MOUNT_LETTER}:SimsMedievalSetup.exe
        winwait, Choose Setup Language
        if ( w_opt_unattended > 0 ) {
            send {Enter}
            SetTitleMatchMode, 2
            winwait, - InstallShield Wizard
            ControlClick &Next >, - InstallShield Wizard
            sleep 1000
            send uuuuuu{Tab}{Tab}{Enter}
            WinWait, Sims, License
            ControlClick Button3   ; Accept
            sleep 1000
            ControlClick Button1   ; Next
            sleep 1000
            send {Raw}$W_KEY
            send {Enter}
            winwait, - InstallShield Wizard, Setup Type
            ControlClick &Complete    ; was not defaulting to complete?
            send {Enter}
            winwait, - InstallShield Wizard, Click Install to begin
            send {Enter}

            ; Handle optional dialogs
            ; In Wine-1.3.16 and lower, before
            ; http://www.winehq.org/pipermail/wine-cvs/2011-March/076262.html,
            ; wine didn't claim to already have .net 4 installed,
            ; and ran into bug 25535.
            Loop
            {
                ; .net 4 install sometimes fails nicely
                ifWinExist,, .NET Framework 4 has not been installed
                {
                    ControlClick Button3    ; Finish
                }
                ; .net 4 install sometimes explodes
                ifWinExist .NET Framework Initialization Error
                {
                    send {Enter}
                }
                ifWinExist, Sims, Customer Experience Improvement
                {
                    send {Enter}           ; Next
                }
                ifWinExist, - InstallShield Wizard, Complete
                    break
                sleep 1000
            }
        }
        winwait, - InstallShield Wizard, Complete
        if ( w_opt_unattended > 0 ) {
            ControlClick Button1   ; Do not view readme
            send {Enter}           ; Finish
        }
        winwaitclose
    "

    # DVD region code is last digit.
    # FIXME: download appropriate one rather than just US version.
    w_download http://akamai.cdn.ea.com/eadownloads/u/f/sims/sims/patches/TheSimsMedievalPatch_1.1.10.00001_Update.exe 7214ced8af7315741e05024faeacf9053b999b1b

    cd "$W_CACHE"/$W_PACKAGE
    w_ahk_do "
        SetTitleMatchMode, 2
        SetWinDelay 500
        run TheSimsMedievalPatch_1.1.10.00001_Update.exe
        winwait, Medieval, will reset any in-progress quests
        send {Enter}
        winwait, Medieval, Welcome
        if ( w_opt_unattended > 0 ) {
            send {Enter}
        }
        winwait, - InstallShield Wizard, Complete
        if ( w_opt_unattended > 0 ) {
            ControlClick Finish, - InstallShield Wizard
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata sims3_gen games \
    title="The Sims 3: Generations (DRM broken on Wine)" \
    publisher="EA" \
    year="2011" \
    media="dvd" \
    file1="Sims3EP04.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Electronic Arts/The Sims 3 Generations/Game/Bin/TS3EP04.exe" \
    wine_showstoppers="26273"

load_sims3_gen()
{
    if [ ! -f "$W_PROGRAMS_X86_WIN/Electronic Arts/The Sims 3/Game/Bin/TS3.exe" ]
    then
        w_die "You must have sims3 installed to install sims3_gen!"
    fi

    w_read_key
    w_mount Sims3EP04

    # Default lang, USA, accept defaults, uncheck EA dl mgr, uncheck readme
    w_ahk_do "
        SetTitleMatchMode, 2
        SetWinDelay 1000
        run ${W_ISO_MOUNT_LETTER}:Sims3EP04Setup.exe
        winwait, - InstallShield Wizard
        if ( w_opt_unattended > 0 ) {
            send {Enter}
            loop
            {
                SetTitleMatchMode, 2
                ifwinexist, - InstallShield Wizard, Setup will now attempt to update
                {
                    ControlClick, Button1, - InstallShield Wizard
                    sleep 1000
                    winwait, - InstallShield Wizard, Setup has finished updating The Sims
                    sleep 1000
                    controlclick, Button1, - InstallShield Wizard
                    sleep 1000
                }
                ifwinexist, Sims, License
                {
                    winactivate, Sims, License
                    sleep 1000
                    ControlClick, Button3
                    sleep 1000
                    ControlClick, Button1
                    sleep 1000
                    break
                }
                sleep 1000
            }
            winwait, Sims, Please enter the entire Registration Code
            sleep 1000
            send {Raw}$W_KEY
            send {Enter}
            winwait, - InstallShield Wizard, Setup Type
            ControlClick &Complete    ; was not defaulting to complete?
            send {Enter}
            winwait, - InstallShield Wizard, Click Install to begin
            send {Enter}
            winwait, - InstallShield Wizard, Would you like to install the latest
            sleep 1000
            ControlClick, Button4 ; No thanks
            sleep 1000
            ControlClick, Button1
            sleep 1000
        }
        winwait, - InstallShield Wizard, Complete
        if ( w_opt_unattended > 0 ) {
            ControlClick Button1   ; Do not view readme
            send {Enter}           ; Finish
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata splitsecond games \
    title="Split Second" \
    publisher="Disney" \
    year="2010" \
    media="dvd" \
    file1="SplitSecond.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Disney Interactive Studios/Split Second/SplitSecond.exe"

load_splitsecond()
{
    # Key is used in first run activation, no need to read it here.
    w_mount SplitSecond

    # Aborts with dialog about FirewallInstallHelper.dll if that's not on the path (e.g. in current dir)
    cd "$W_ISO_MOUNT_ROOT"
    w_ahk_do "
        SetTitleMatchMode, 2
        run setup.exe
        winwait, Split, Language
        sleep 500
        ControlClick, Next, Split, Language ; FIXME: Use button name
        winwait, Split, game installation
        sleep 500
        ControlClick, Button1, Split, game installation
        winwait, Split, license
        sleep 500
        ControlClick, Button5, Split, license
        sleep 500
        ControlClick, Button2, Split, license
        winwait, Split, DirectX
        sleep 500
        ControlClick, Button5, Split, DirectX
        sleep 500
        ControlClick, Button2, Split, DirectX
        winwait, Split, installation method
        sleep 500
        controlclick, Next, Split, installation method ; FIXME: Use button name
        winwait, DirectX needs to be updated
        sleep 500
        send {Enter}
        winwait, Split, begin
        sleep 500
        ControlClick, Button1
        winwait, Split, completed
        sleep 500
        ControlClick, Button1, Split
        sleep 500
        ControlClick, Button4, Split
    "
}

#----------------------------------------------------------------

w_metadata splitsecond_demo games \
    title="Split Second Demo" \
    publisher="Disney" \
    year="2010" \
    media="manual_download" \
    file1="SplitSecondDemo_FilePlanet.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Disney Interactive Studios/Split Second/SplitSecondDEMO.exe"

load_splitsecond_demo()
{
    w_download_manual http://www.fileplanet.com/212404/210000/fileinfo/Split/Second-Demo SplitSecondDemo_FilePlanet.exe 72b070712cfe951297263fae143521b45dae16b4

    if w_workaround_wine_bug 22774 "" 1.3.0
    then
        w_warn "On Wine, install takes an extra 7 minutes at the end, please be patient."
    fi

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        run, SplitSecondDemo_FilePlanet.exe
        winwait, Split, Language
        ;ControlClick, Next, Split, Language  ; does not quite work, have to use {Enter} instead
        Send {Enter}
        winwait, Split, game installation
        ControlClick, Button1, Split, game installation
        winwait, Split, license
        ControlClick, Button5, Split, license
        ControlClick, Button2, Split, license
        winwait, Split, DirectX
        ControlClick, Button5, Split, DirectX
        ControlClick, Button2, Split, DirectX
        winwait, Split, installation path
        ControlClick, Button1, Split, installation path
        winwait, Split, Game features
        ControlClick, Button2, Split, Game features
        winwait, Split, start copying
        ControlClick, Button1, Split, start copying
        winwait, Split, completed
        ControlClick, Button1, Split, completed
        ControlClick, Button4, Split, completed
    "
}

#----------------------------------------------------------------

w_metadata spore games \
    title="Spore" \
    publisher="EA" \
    year="2008" \
    media="dvd" \
    file1="SPORE.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Electronic Arts/SPORE/Sporebin/SporeApp.exe"

load_spore()
{
    w_mount SPORE

    w_read_key

    w_ahk_do "
        SetTitleMatchMode, 2
        run, ${W_ISO_MOUNT_LETTER}:SPORESetup.exe
        winwait, Language
        if ( w_opt_unattended > 0 ) {
            sleep 500
            controlclick, Button1
            winwait, SPORE, Welcome
            sleep 500
            controlclick, Button1
            winwait, SPORE, License
            sleep 500
            controlclick, Button3
            sleep 500
            controlclick, Button1
            winwait, SPORE, Registration Code
            send {RAW}$W_KEY
            sleep 500
            controlclick, Button2
            winwait, SPORE, Setup Type
            sleep 500
            controlclick, Button6
            winwait, SPORE, Shortcut
            sleep 500
            controlclick, Button6
            winwait, SPORE, begin
            sleep 500
            controlclick, Button1
            winwait, Question
            ; download managers are usually a pain, so always say no to such questions
            sleep 500
            controlclick, Button2
        }
        winwait, SPORE, complete
        sleep 500
        if ( w_opt_unattended > 0 ) {
            controlclick, Button1
            sleep 500
            controlclick, Button2
            sleep 500
            controlclick, Button4
        }
        winwaitclose, SPORE, complete
    "
}

#----------------------------------------------------------------

w_metadata spore_cc_demo games \
    title="Spore Creature Creator trial" \
    publisher="EA" \
    year="2008" \
    media="download" \
    file1="792248d6ad421d577132c2b648bbed45_scc_trial_na.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Electronic Arts/SPORE/Sporebin/SporeCreatureCreator.exe"

load_spore_cc_demo()
{
    w_download http://lvlt.bioware.cdn.ea.com/u/f/eagames/spore/scc/promo/792248d6ad421d577132c2b648bbed45_scc_trial_na.exe 06da5558e6ebbc39d2fac955eceab78cf8470e07

    w_info "The installer runs on for about a minute after it's done."

    cd "$W_CACHE/$W_PACKAGE"
    if test "$W_OPT_UNATTENDED"
    then
        w_ahk_do "
            SetWinDelay 1000
            SetTitleMatchMode, 2
            run $file1
            winwait, Wizard, Welcome to the SPORE
            send N
            winwait, Wizard, Please read the following
            send a
            send N
            winwait, Wizard, your setup
            send N
            winwait, Wizard, options below
            send N
            winwait, Wizard, We're ready
            ;send i       ; didn't take once?
            ControlClick, Button1
            winwait, Question, do not install the latest
            send N        ; reject EA Download Manager
            winwait, Wizard, Launch
            send {SPACE}{DOWN}{SPACE}{ENTER}
            winwaitclose
        "
        while ps | grep $file1 | grep -v grep > /dev/null
        do
            w_info "Waiting for installer to finish."
            sleep 2
        done
    else
        w_try "$WINE" "$file1"
    fi
}

#----------------------------------------------------------------

w_metadata starcraft2_demo games \
    title="Starcraft II Demo" \
    publisher="Blizzard" \
    year="2010" \
    media="manual_download" \
    file1="SC2-WingsOfLiberty-enUS-Demo-Installer.zip" \
    installed_exe1="$W_PROGRAMS_X86_WIN/StarCraft II Demo/StarCraft II.exe"

load_starcraft2_demo()
{
    w_download_manual http://www.fileplanet.com/217982/210000/fileinfo/Starcraft-2-Demo SC2-WingsOfLiberty-enUS-Demo-Installer.zip 4c06ad755fbde73f135a7359bf6bfdbd2c6eb00e

    cd "$W_TMP"
    w_try_unzip . "$W_CACHE/$W_PACKAGE"/SC2-WingsOfLiberty-enUS-Demo-Installer.zip

    w_ahk_do "
        SetTitleMatchMode, 2
        Run, Installer.exe
        WinWait, StarCraft II Installer
        if ( w_opt_unattended > 0 ) {
            sleep 500
            ControlClick, x300 y200
            winwait, End User License Agreement
            winactivate
            ;MouseMove, 300, 300
            ;Click WheelDown, 70
            Sleep, 1000
            ControlClick, Button2  ; Accept
            winwaitclose
            winwait, StarCraft II Installer
            sleep 1000
            ControlClick, x800 y500
            ; Is there any better wait to await completion?
            Loop {
                PixelGetColor, color, 473, 469   ; the 1 in 100%
                ; The digits are drawn white, but because the whole
                ; window is flickering, it cycles through about 20
                ; brightnesses.  Check a bunch of them to reduce
                ; chances of getting stuck for a long time.
                ifEqual, color, 0xffffff
                    break
                ifEqual, color, 0xf4f4f4
                    break
                ifEqual, color, 0xf1f1f1
                    break
                ifEqual, color, 0xf0f0f0
                    break
                ifEqual, color, 0xeeeeee
                    break
                ifEqual, color, 0xebebeb
                    break
                ifEqual, color, 0xe4e4e4
                    break
                sleep 500 ; changes rapidly, so sample often
            }
            ControlClick, x800 y500   ; Finish
            winwaitclose
            ; no way to tell game to not start?
            process, wait, SC2.exe
            sleep 2000
            process, close, SC2.exe
        }
        "
}

#----------------------------------------------------------------

w_metadata theundergarden_demo games \
    title="The UnderGarden Demo" \
    publisher="Atari" \
    year="2010" \
    media="manual_download" \
    file1="TheUnderGarden_PC_B34_SRTB.30_28OCT10.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/The UnderGarden/TheUndergarden.exe"

load_theundergarden_demo()
{
    w_download_manual http://www.bigdownload.com/games/the-undergarden/pc/the-undergarden-demo TheUnderGarden_PC_B34_SRTB.30_28OCT10.exe acf90c422ac2f2f242100f39bedfe7df0c95f7a

    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        SetTitleMatchMode, 2
        Run, TheUnderGarden_PC_B34_SRTB.30_28OCT10.exe
        WinWait,WinRAR
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick Button2 ; Install
            WinWait,Select Setup Language, during
            Sleep 500
            ControlClick TNewButton1 ;OK
            WinWait,Setup - The UnderGarden, your
            Sleep 500
            ControlClick TNewButton1 ;OK
            WinWait,Setup - The UnderGarden, License
            Sleep 500
            ControlClick TNewRadioButton1 ; accept
            Sleep 500
            ControlClick TNewButton2 ; Next
            WinWait,Setup - The UnderGarden, different
            Sleep 500
            ControlClick TNewButton3 ;Next
            WinWait,Setup - The UnderGarden, shortcuts
            Sleep 500
            ControlClick TNewButton4 ;OK
            WinWait,Setup - The UnderGarden, additional
            Sleep 500
            ControlFocus,TNewCheckListBox1,desktop
            Sleep 500
            Send {Space}
            Sleep 500
            ControlClick TNewButton4 ; Next
            WinWait,Setup - The UnderGarden, review
            Sleep 500
            ControlClick TNewButton4 ;Install
            WinWait,Microsoft Visual C, Visual
            Sleep 500
            ControlClick Button13 ;Cancel
            WinWait,Microsoft Visual C, want
            Sleep 500
            ControlClick Button1 ;Yes
            WinWait,Microsoft Visual C, chosen
            Sleep 500
            ControlClick Button2 ;Finish
            WinWait,Framework 3, Press
            Sleep 500
            ControlClick Button21 ;Cancel
            WinWait,Framework 3, want
            Sleep 500
            ControlClick Button1 ;Yes
            WinWait,Installing Microsoft, Runtime
            Sleep 500
            ControlClick Button6 ;Cancel
        }
        WinWait,Setup,launched
        if ( w_opt_unattended > 0 ) {
            Sleep 500
            ControlClick TNewButton4 ;Finish
        }
        WinWaitClose,Setup,launched
    "
}

#----------------------------------------------------------------

w_metadata tmnationsforever games \
    title="TrackMania Nations Forever" \
    publisher="Nadeo" \
    year="2009" \
    media="download" \
    file1="tmnationsforever_setup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/TmNationsForever/TmForever.exe"

load_tmnationsforever()
{
    # Before:      cab0cf66db0471bc2674a3b1aebc35de0bca6ed0
    # 29 Mar 2011: 23388798d5c90ad4a233b4cd7e9fcafd69756978
    w_download "http://files.trackmaniaforever.com/tmnationsforever_setup.exe" 23388798d5c90ad4a233b4cd7e9fcafd69756978

    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        SetTitleMatchMode, 2
        Run, tmnationsforever_setup.exe
        WinWait,Select Setup Language
        if ( w_opt_unattended > 0 ) {
            Sleep 1000
            ControlClick TNewButton1 ; OK
            WinWait,Setup - TmNationsForever,Welcome
            Sleep 1000
            ControlClick TNewButton1 ; Next
            WinWait,Setup - TmNationsForever,License
            Sleep 1000
            ControlClick TNewRadioButton1 ; Accept
            Sleep 1000
            ControlClick TNewButton2 ; Next
            WinWait,Setup - TmNationsForever,Where
            Sleep 1000
            ControlClick TNewButton3 ; Next
            WinWait,Setup - TmNationsForever,shortcuts
            Sleep 1000
            ControlClick TNewButton4 ; Next
            WinWait,Setup - TmNationsForever,perform
            Sleep 1000
            ControlClick TNewButton4 ; Next
            WinWait,Setup - TmNationsForever,installing
            Sleep 1000
            ControlClick TNewButton4 ; Install
        }
        WinWait,Setup - TmNationsForever,finished
        if ( w_opt_unattended > 0 ) {
            Sleep 1000
            ControlFocus, TNewCheckListBox1, TmNationsForever, finished
            Sleep 1000
            Send {Space} ; don't start game
            ControlClick TNewButton4 ; Finish
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata trainztcc_2004 games \
    title="Trainz: The Complete Collection: TRS2004" \
    publisher="Paradox Interactive" \
    year="2008" \
    media="dvd" \
    file1="TRS2006DVD.iso" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Auran/TRS2004/TRS2004.exe"

load_trainztcc_2004()
{
    w_call mfc42

    w_read_key
    # yup, they got the volume name wrong
    w_mount TRS2006DVD
    cd ${W_ISO_MOUNT_ROOT}/TRS2004_SP4_DVD_Installer_BUILD_2370/Installer/Disk1
    w_ahk_do "
        SetTitleMatchMode, 2
        SetWinDelay 500
        run setup.exe
        if ( w_opt_unattended > 0 ) {
            winwait TRS2004 Setup, Please install the latest drivers
            send {Enter}
            winwait TRS2004, Welcome
            send {Enter}
            winwait TRS2004, License
            ControlClick Button2
            winwait TRS2004, serial
            winactivate
            send ${W_RAW_KEY}{Enter}
            winwait TRS2004, Destination
            send {Enter}
            winwait Install DirectX
            send n
            winwait Windows Update, Your computer already
            send {Enter}
        }
        winwait TRS2004, Complete
        if ( w_opt_unattended > 0 ) {
            send {Space}     ; uncheck View Readme
            send {Enter}     ; Finish
        }
        winwaitclose
    "

    # And, while we're at it, also install the accompanying paint shed app
    cd ${W_ISO_MOUNT_ROOT}/TRAINZ_PAINTSHED
    w_ahk_do "
        SetTitleMatchMode, 2
        SetWinDelay 500
        run Trainz_Paint_Shed_Setup.exe
        if ( w_opt_unattended > 0 ) {
            winwait Trainz Paint Shed, Welcome
            send {Enter}
            winwait Trainz Paint Shed, License
            send a           ; accept
            send {Enter}     ; Next
            winwait Trainz Paint Shed, Destination
            send {Enter}
            winwait Trainz Paint Shed, Install
            send {Enter}
        }
        winwait Trainz Paint Shed, Complete
        if ( w_opt_unattended > 0 ) {
            send {Enter}     ; Finish
        }
        winwaitclose
    "
}

#----------------------------------------------------------------

w_metadata sammax301_demo games \
    title="Sam & Max 301: The Penal Zone" \
    publisher="Telltale Games" \
    year="2010" \
    media="manual_download" \
    file1="SamMax301_PC_Setup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Telltale Games/Sam and Max - The Devil's Playhouse/The Penal Zone/SamMax301.exe"

load_sammax301_demo()
{
    w_download_manual "http://www.fileplanet.com/211314/210000/fileinfo/Sam-&-Max:-Devil's-Playhouse---Episode-One-Demo" SamMax301_PC_Setup.exe 83f47b7f3a5074a6e29bdc9b4f1fd2c4471d9641

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        SetWinDelay 500
        run SamMax301_PC_Setup.exe
        winwait Sam and Max The Penal Zone Setup, Welcome
        if ( w_opt_unattended > 0 ) {
            controlclick button2 ; Next
            winwait Sam and Max The Penal Zone Setup, DirectX
            controlclick button5 ; Uncheck check directx
            controlclick button2 ; Next
            winwait Sam and Max The Penal Zone Setup, License
            controlclick button2 ; I Agree
            winwait Sam and Max The Penal Zone Setup, Location
            controlclick button2 ; Install
            winwait Sam and Max The Penal Zone Setup, Finish
            controlclick button4 ; Uncheck play now
            controlclick button5 ; Uncheck create shortcut
            controlclick button2 ; Finish
        }
        winwaitclose Sam and Max The Penal Zone Setup
    "
}

#----------------------------------------------------------------

w_metadata sammax304_demo games \
    title="Sam & Max 304: Beyond the Alley of the Dolls" \
    publisher="Telltale Games" \
    year="2010" \
    media="manual_download" \
    file1="SamMax304_PC_setup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Telltale Games/Sam and Max - The Devil's Playhouse/Beyond the Alley of the Dolls/SamMax304.exe"

load_sammax304_demo()
{
    w_download_manual "http://www.fileplanet.com/214770/210000/fileinfo/Sam-&-Max:-The-Devi's-Playhouse---Beyond-the-Alley-of-the-Dolls-Demo" SamMax304_PC_setup.exe 1a385a1f1e83770c973e6457b923b7a44bbe44d8

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetTitleMatchMode, 2
        Run, $file1
        WinWait,Sam and Max Beyond the Alley of the Dolls Setup
        if ( w_opt_unattended > 0 ) {
            ControlClick Button2 ; Next
            WinWait,Sam and Max Beyond the Alley of the Dolls Setup,DirectX
            ControlClick Button2 ; Next - Directx check defaulted
            WinWait,Sam and Max Beyond the Alley of the Dolls Setup,License
            ControlClick Button2 ; Agree
            WinWait,Sam and Max Beyond the Alley of the Dolls Setup,Location
            ControlClick Button2 ; Install
            WinWait,Sam and Max Beyond the Alley of the Dolls Setup,Finish
            ControlClick Button4 ; Uncheck Play Now
            ControlClick Button2 ; Finish
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata tropico3_demo games \
    title="Tropico 3 Demo" \
    publisher="Kalypso Media GmbH" \
    year="2009" \
    media="manual_download" \
    file1="Tropico3Demo.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Kalypso/Tropico 3 Demo/Tropico3 Demo.exe"

load_tropico3_demo()
{
    w_download_manual "http://www.tropico3.com/?p=downloads" Tropico3Demo.exe e031749db346ac3a87a675787c81eb1ca8cb5909

    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        SetWinDelay 1000
        SetTitleMatchMode, 2
        Run, Tropico3Demo.exe
        WinWait,Installer
        if ( w_opt_unattended > 0 ) {
            ControlClick Button1 ; OK
            WinWait,Tropico,Welcome
            ControlClick Button2 ; Next
            WinWait,Tropico,License
            ControlClick Button2 ; Agree
            WinWait,Tropico,Typical
            ControlClick Button2 ; Next
        }
        WinWait,Tropico,Completing
        if ( w_opt_unattended > 0 ) {
            ControlClick Button4 ; Uncheck Run Now
            ControlClick Button2 ; Finish
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata singularity games \
    title="Singularity" \
    publisher="Activision" \
    year="2010" \
    media="dvd" \
    file1="SNG_DVD.iso"

load_singularity()
{
    w_read_key
    w_mount SNG_DVD

    w_ahk_do "
        run ${W_ISO_MOUNT_LETTER}:setup.exe
        winwait, Activision(R) - InstallShield, Select the language for the installation from the choices below.
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            controlclick, Button1, Activision(R) - InstallShield, Select the language for the installation from the choices below.
            sleep 1000
            winwait, Singularity(TM), Keycode Check
            sleep 1000
            Send $W_KEY
            sleep 1000
            Send {Enter}
            ; Well this is annoying...
            Winwait, Keycode Check, The Keycode you entered appears to be valid.
            sleep 1000
            Send {Enter}
            winwait, Singularity(TM), The InstallShield Wizard will install Singularity(TM) on your computer
            sleep 1000
            controlclick, Button1, Singularity(TM), The InstallShield Wizard will install Singularity(TM) on your computer
            winwait, Singularity(TM), Please read the following license agreement carefully
            sleep 1000
            controlclick, Button5, Singularity(TM), Please read the following license agreement carefully
            sleep 1000
            controlclick, Button2, Singularity(TM), Please read the following license agreement carefully
            winwait, Singularity(TM), Minimum System Requirements
            sleep 1000
            controlclick, Button1, Singularity(TM), Minimum System Requirements
            winwait, Singularity(TM), Select the setup type to install
            controlclick, Button4, Singularity(TM), Select the setup type to install
        }
        ; Loop until installer window has been gone for at least two seconds
        Loop
        {
            sleep 1000
            IfWinExist, Singularity
                continue
            IfWinExist, Activision
                continue
            sleep 1000
            IfWinExist, Singularity
                continue
            IfWinExist, Activision
                continue
            break
        }
        "

    # Clean up crap left over in c:\ when the installer runs the vc 2008 redistributable installer
    cd "$W_DRIVE_C"
    rm -f VC_RED.* eula.*.txt globdata.ini install.exe install.ini install.res.*.dll vcredist.bmp
}

#----------------------------------------------------------------

w_metadata wglgears benchmarks \
    title="wglgears" \
    publisher="Clinton L. Jeffery" \
    year="2005" \
    media="download" \
    file1="wglgears.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/misc/wglgears.exe"

load_wglgears()
{
    w_download http://www2.cs.uidaho.edu/~jeffery/win32/wglgears.exe d65d2098bc11af76cb614946342913b1af62924d
    mkdir -p "$W_PROGRAMS_X86_UNIX/misc"
    cp "$W_CACHE"/wglgears/wglgears.exe "$W_PROGRAMS_X86_UNIX/misc"
    chmod +x "$W_PROGRAMS_X86_UNIX/misc/wglgears.exe"
}

#----------------------------------------------------------------

w_metadata stalker_pripyat_bench benchmarks \
    title="S.T.A.L.K.E.R.: Call of Pripyat benchmark" \
    publisher="GSC Game World" \
    year="2009" \
    media="manual_download" \
    file1="stkcop-bench-setup.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Call Of Pripyat Benchmark/Benchmark.exe"

load_stalker_pripyat_bench()
{
    # Much faster
    w_download_manual http://www.bigdownload.com/games/stalker-call-of-pripyat/pc/stalker-call-of-pripyat-benchmark stkcop-bench-setup.exe 8691c3f289ecd0521bed60ffd46e65ad080206e0
    #w_download http://files.gsc-game.com/st/bench/stkcop-bench-setup.exe 8691c3f289ecd0521bed60ffd46e65ad080206e0

    cd "$W_CACHE/$W_PACKAGE"

    # FIXME: a bit fragile, if you're browsing the web while installing, it sometimes gets stuck.
    w_ahk_do "
        SetTitleMatchMode, 2
        run stkcop-bench-setup.exe
        WinWait,Setup - Call Of Pripyat Benchmark
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            ControlClick TNewButton1 ; Next
            WinWait,Setup - Call Of Pripyat Benchmark,License
            sleep 1000
            ControlClick TNewRadioButton1 ; accept
            sleep 1000
            ControlClick TNewButton2 ; Next
            WinWait,Setup - Call Of Pripyat Benchmark,Destination
            sleep 1000
            ControlClick TNewButton3 ; Next
            WinWait,Setup - Call Of Pripyat Benchmark,shortcuts
            sleep 1000
            ControlClick TNewButton4 ; Next
            WinWait,Setup - Call Of Pripyat Benchmark,performed
            sleep 1000
            ControlClick TNewButton4 ; Next
            WinWait,Setup - Call Of Pripyat Benchmark,ready
            sleep 1000
            ControlClick, TNewButton4 ; Next  (nah, who reads doc?)
        }
        WinWait,Setup - Call Of Pripyat Benchmark,finished
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            Send {Space}  ; uncheck launch
            sleep 1000
            ControlClick TNewButton4 ; Finish
        }
        WinWaitClose,Setup - Call Of Pripyat Benchmark,finished
    "

    if w_workaround_wine_bug 24868
    then
        w_call d3dx9_31
        w_call d3dx9_42
    fi
}

#----------------------------------------------------------------

w_metadata torchlight games \
    title="Torchlight - boxed version" \
    publisher="Runic Games" \
    year="2009" \
    media="dvd" \
    file1="Torchlight.iso"

load_torchlight()
{
    w_mount "Torchlight"
    w_ahk_do "
        SetTitleMatchMode, 2
        Run, ${W_ISO_MOUNT_LETTER}:Torchlight.exe
        WinWait, Torchlight Setup, This wizard will guide
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            ControlClick, Button2, Torchlight Setup, This wizard will guide
            WinWait, Torchlight Setup, Please review the license terms
            sleep 1000
            ControlClick, Button2, Torchlight Setup, Please review the license terms
            WinWait, Torchlight Setup, Choose Install Location
            sleep 1000
            ControlClick, Button2, Torchlight Setup, Choose Install Location
            WinWait, Torchlight Setup, Installation Complete
            sleep 1000
            ControlClick, Button2, Torchlight Setup, Installation Complete
            WinWait, Torchlight Setup, Completing the Torchlight Setup Wizard
            sleep 1000
            ControlClick, Button4, Torchlight Setup, Completing the Torchlight Setup Wizard
            ControlClick, Button2, Torchlight Setup, Completing the Torchlight Setup Wizard
        }
        WinWaitClose, Torchlight Setup
    "
}

#----------------------------------------------------------------

w_metadata twfc games \
    title="Transformers: War for Cybertron" \
    publisher="Activision" \
    year="2010" \
    media="dvd" \
    file1="TWFC_DVD.iso"

load_twfc()
{
    w_read_key
    w_mount TWFC_DVD

    w_ahk_do "
        run ${W_ISO_MOUNT_LETTER}:setup.exe
        SetTitleMatchMode, 2
        winwait, Activision, Select the language for the installation
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            controlclick, Button1, Activision, Select the language for the installation
            winwait, Transformers, Press NEXT to verify your key
            sleep 1000
            send $W_KEY
            send {Enter}
            winwait, Keycode Check, The Keycode you entered appears to be valid
            sleep 1000
            send {Enter}
            winwait, Transformers, The InstallShield Wizard will install Transformers
            sleep 1000
            controlclick, Button1, Transformers, The InstallShield Wizard will install Transformers
            winwait, Transformers, License Agreement
            sleep 1000
            controlclick, Button5, Transformers, License Agreement
            sleep 1000
            controlclick, Button2, Transformers, License Agreement
            winwait, Transformers, Minimum System Requirements
            sleep 1000
            controlclick, Button1, Transformers, Minimum System Requirements
            winwait, Transformers, Select the setup type to install
            sleep 1000
            controlclick, Button4, Transformers, Select the setup type to install
        }
        ; Installer exits silently. Prevent an early umount
        Loop
        {
            sleep 1000
            IfWinExist, Transformers
                continue
            IfWinExist, Activision
                continue
            sleep 1000
            IfWinExist, Transformers
                continue
            IfWinExist, Activision
                continue
            break
        }
    "

    # Clean up crap left over in c:\ when the installer runs the vc 2008 redistributable installer
    cd "$W_DRIVE_C"
    rm -f VC_RED.* eula.*.txt globdata.ini install.exe install.ini install.res.*.dll vcredist.bmp
}

#----------------------------------------------------------------

w_metadata typingofthedead_demo games \
    title="Typing of the Dead Demo" \
    publisher="Sega" \
    year="1999" \
    media="manual_download" \
    file1="Tod_e_demo.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/SEGA/TOD-Demo/Tod_e_demo.exe"

load_typingofthedead_demo()
{
    w_download "http://www.fileplanet.com/54947/50000/fileinfo/The-Typing-of-the-Dead-Demo" 96fe3edb2431210932af840e29c59bce6b7fc80f
    cd "$W_TMP"
    w_try_unzip . "$W_CACHE/$W_PACKAGE/tod-demo.zip"
    w_ahk_do "
        SetTitleMatchMode, 2
        run SETUP.EXE
        if ( w_opt_unattended > 0 ) {
            WinWait,InstallShield Wizard,where
            sleep 1000
            ControlClick Button1 ; Next
            WinWait,InstallShield Wizard,icons
            sleep 1000
            ControlClick Button2 ; Next
        }
        ; installer crashes here?
        Sleep 20000
    "
}

#----------------------------------------------------------------

w_metadata ut3 games \
    title="Unreal Tournament 3" \
    publisher="Midway Games" \
    year="2007" \
    media="dvd" \
    file1="UT3_RC7.iso" \
    file2="UT3Patch5.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Unreal Tournament 3/Binaries/UT3.exe"

load_ut3()
{
    w_download_manual "http://www.filefront.com/13709855/UT3Patch5.exe" UT3Patch5.exe
    w_try w_mount UT3_RC7

    w_ahk_do "
        run ${W_ISO_MOUNT_LETTER}:SetupUT3.exe
        SetTitleMatchMode, slow    ; else can't see EULA text
        SetTitleMatchMode, 2
        SetWinDelay 1000
        WinWait, Choose Setup Language
        if ( w_opt_unattended > 0 ) {
            ControlClick Button1   ; OK
            WinWait, Unreal Tournament 3, GAMESPY ; License Agreement
            ControlClick Button2   ; Yes
            WinWait, Unreal Tournament 3, UnrealEd ; License Agreement
            ControlClick Button2   ; Yes
            WinWait, , Choose Destination
            ControlClick Button1   ; Next
            WinWait, AGEIA PhysX v7.09.13 Setup, License
            ControlClick Button3   ; Accept
            sleep 1000
            ControlClick Button4   ; Next
            WinWait, AGEIA PhysX v7.09.13, Finish
            ControlClick Button1   ; Finish
            ; game now begins installing
        }
        WinWait, , InstallShield Wizard Complete
        if ( w_opt_unattended > 0 ) {
            ControlClick Button4   ; Finish
        }
        WinWaitClose
    "

    cd "$W_CACHE/$W_PACKAGE"

    w_ahk_do "
        SetTitleMatchMode, 2
        run UT3Patch5.exe
        WinWait, License
        if ( w_opt_unattended > 0 ) {
            ControlClick Button1   ; Accept
            WinWait, End User License Agreement
            ControlClick Button1   ; Accept
            WinWait, Patch UT3
            ControlClick Button1   ; Yes
        }
        WinWait, , UT3 was successfully patched!
        if ( w_opt_unattended > 0 ) {
            ControlClick Button1   ; OK
        }
        WinWaitClose
    "
}

#----------------------------------------------------------------

w_metadata wog games \
    title="World of Goo Demo" \
    publisher="2D Boy" \
    year="2008" \
    media="download" \
    file1="WorldOfGooDemo.1.0.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/WorldOfGooDemo/WorldOfGoo.exe"

load_wog()
{
    if ! test -f "$W_CACHE/wog/WorldOfGooDemo.1.0.exe"
    then
        # Get temporary download location
        w_download "http://www.worldofgoo.com/dl2.php?lk=demo&filename=WorldOfGooDemo.1.0.exe"
        URL=`cat "$W_CACHE/wog/dl2.php?lk=demo&filename=WorldOfGooDemo.1.0.exe" |
           grep WorldOfGooDemo.1.0.exe | sed 's,.*http,http,;s,".*,,'`
        rm "$W_CACHE/wog/dl2.php?lk=demo&filename=WorldOfGooDemo.1.0.exe"

        w_download "$URL" e61d8253b9fe0663cb3c69018bb3d2ec6152d488
    fi

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        SetWinDelay 500
        run WorldOfGooDemo.1.0.exe
        winwait, World of Goo Setup, License Agreement
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            WinActivate
            send {Enter}
            winwait, World of Goo Setup, Choose Components
            send {Enter}
            winwait, World of Goo Setup, Choose Install Location
            send {Enter}
            winwait, World of Goo Setup, Thank you
            ControlClick, Make me dirty right now, World of Goo Setup, Thank you
            send {Enter}
        }
        winwaitclose, World of Goo Setup
        "
}

#----------------------------------------------------------------

w_metadata zootycoon2_demo games \
    title="Zoo Tycoon 2 demo" \
    publisher="Microsoft" \
    year="2004" \
    media="download" \
    file1="Zoo2Trial.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Microsoft Games/Zoo Tycoon 2 Trial Version/zt2demoretail.exe"

load_zootycoon2_demo()
{
    w_download "http://download.microsoft.com/download/9/f/6/9f6a95f0-f34a-4312-9749-77b81d3de245/Zoo2Trial.exe" 60ad1bb34351f97b579c58234b926055f7979126

    cd "$W_CACHE/$W_PACKAGE"
    w_ahk_do "
        ; Uses winwaitactive, because the windows appear and immediately after another window
        ; gets in the way, then disappears after a second or so
        SetTitleMatchMode, 2
        run Zoo2Trial.exe
        winwaitclose, APPMESSAGE
        winwaitactive, Zoo Tycoon 2 Trial, AUTORUN
        if ( w_opt_unattended > 0 ) {
            sleep 1000
            controlclick, CButtonClassName1, Zoo Tycoon 2 Trial, AUTORUN
            winwaitclose, APPMESSAGE
            winwaitactive, Zoo Tycoon 2 Trial, INSTALLTYPE
            ; 1 second was not enough.
            sleep 3000
            controlclick, CButtonClassName1, Zoo Tycoon 2 Trial, INSTALLTYPE
        }
        winwaitactive, Zoo Tycoon 2 Trial, COMPLETE
        winclose, Zoo Tycoon 2 Trial, COMPLETE
        "
}

#----------------------------------------------------------------
# Gog.com games
#----------------------------------------------------------------

w_metadata beneath_a_steel_sky_gog games \
    title="Beneath a Steel Sky (GOG.com, free)" \
    publisher="Virgin Interactive" \
    year="1994" \
    file1="setup_beneath_a_steel_sky.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/GOG.com/Beneath a Steel Sky/ScummVM/scummvm.exe"

load_beneath_a_steel_sky_gog()
{
    winetricks_load_gog "beneath_a_steel_sky" "Beneath a Steel Sky" "" "TsCheckBox4" "ScummVM\\scummvm.exe -c \"C:\\Program Files\\GOG.com\\Beneath a Steel Sky\\beneath.ini\" beneath" "" "" "75176395,1f99e12643529baa91fecfb206139a8921d9589c"
}

w_metadata sacrifice_gog games \
    title="Sacrifice (GOG.com)" \
    publisher="Interplay" \
    year="2000" \
    media="manual_download" \
    file1="setup_sacrifice.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/GOG.com/Sacrifice/Sacrifice.exe"

load_sacrifice_gog()
{
    winetricks_load_gog "sacrifice" "Sacrifice" "" "TsCheckBox2" "sacrifice" "" "" "591161642,63e77685599ce20c08b004a9fa3324e466ce1679"
}

w_metadata the_witcher_2_gog games \
    title="The Witcher 2: Assassins of Kings" \
    publisher="Atari" \
    year="2011" \
    media="manual_download" \
    file1="setup_the_witcher_2_ee_3.0.1.17.exe" \
    installed_exe1="$W_PROGRAMS_X86_WIN/GOG.com/The Witcher 2/bin/witcher2.exe"

load_the_witcher_2_gog()
{
    winetricks_load_gog "the_witcher_2" \
        "The Witcher 2 - Assassins of Kings" \
        "setup_the_witcher_2-1.bin,2048477,b826cd7b096fd98eab78517752522b2a3ca8af5e\
        setup_the_witcher_2-2.bin,2050788,a419926e4d02de81d79d586bf893150d3231833c \
        setup_the_witcher_2-3.bin,2050788,6974cadc29fb8a8795aa245c5f8bb24e5e0cff5e \
        setup_the_witcher_2-4.bin,2050788,ed79c1e9456801addf6fd6e687528fa01354b0d8 \
        setup_the_witcher_2-5.bin,1631852,354cb73ae3e73cb88dedc53dd472803862a654cf \
        setup_the_witcher_2.bin,129136,d3aa93bf147e155c5035ae15444916feabfd47b4" \
        "" "bin/witcher2.exe" "" "The Witcher 2" \
        "2308,9ca06383301f242143f69fe08974f9d4d713ac6b"
}

# Brief HOWTO for adding a GOG game:
# - "beneath_a_steel_sky" is the installer exe name, minus "setup_" and ".exe"
# - "Beneath a Steel Sky" is installer window title, minus "Setup - "
# - There are no other files for this game, so this parameter is empty.
#   Otherwise it should be of the following form:
#   file_name[,length[,sha1sum]] [...]
# - "TsCheckBox4" is the control name for the checkbox deciding whether it will
#   install some reader (Foxit in this case, could be Acrobat Reader). That
#   installation is enabled by default, and would just bloat the generic
#   AutoHotKey script, so it gets disabled.
# - "ScummVM\\[...]" is the command line to run the game, as fetched from the
#   shortcut/launcher installer/wine creates, which will be used in BAT scripts
#   created by wisotool
# - The part in the URL which is specific to this game is identical to its "id"
#   (first parameter), so this parameter is left out.
# - The install directory is the same as installer window title (second
#   parameter), so this parameter is left out.
# - Main installer size and sha1sum, separated by a comma.

#----------------------------------------------------------------
# Steam Games
#----------------------------------------------------------------

w_metadata alienswarm_steam games \
    title="Alien Swarm (Steam)" \
    publisher="Valve" \
    year="2010" \
    media="download" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Steam/steamapps/common/alien swarm/swarm.exe"

load_alienswarm_steam()
{
    w_steam_install_game 630 "Alien Swarm"
}

#----------------------------------------------------------------

w_metadata bioshock2_steam games \
    title="Bioshock 2 (Steam)" \
    publisher="2k" \
    year="2010" \
    media="download" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Steam/steamapps/common/bioshock2/blort.exe"

load_bioshock2_steam()
{
    w_steam_install_game 8850 "BioShock 2"
}

#----------------------------------------------------------------

w_metadata borderlands_steam games \
    title="Borderlands (Steam, non-free)" \
    publisher="2K Games" \
    year="2009" \
    media="download" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Steam/steamapps/common/borderlands/Binaries/Borderlands.exe"

load_borderlands_steam()
{
    w_steam_install_game 8980 "Borderlands"
}

#----------------------------------------------------------------

w_metadata civ5_demo_steam games \
    title="Civilization V Demo (Steam)" \
    publisher="2K Games" \
    year="2010" \
    media="download" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Steam/steamapps/common/sid meier's civilization v - demo/CivilizationV.exe"

load_civ5_demo_steam()
{
    # Start AutoHotKey watching for DirectX 9 option in the background, and select it when it comes up
    w_ahk_do  "
        SetWinDelay 500
        loop
        {
            ifWinExist, Sid Meier's Civilization V - Demo - Steam
            {
                winactivate
                click 26,108    ; select directx9
                sleep 500
                click 200,150   ; Play
            }
            ifWinExist, Updating Sid Meier's Civilization V - Demo
            {
                break
            }
            sleep 1000
        }
    " &
    _job=$!
        # While that's running, install the game.
        # You'll see *two* AutoHotKey icons until that first script
        # finds the dialog it's looking for, clicks, and exits.
        w_info "If you already own the full Civ 5 game on Steam, the installer won't even appear."
    w_steam_install_game 65900 "Sid Meier's Civilization V - Demo"
    kill -s HUP $_job   # just in case
}

#----------------------------------------------------------------

w_metadata ruse_demo_steam games \
    title="Ruse Demo (Steam)" \
    publisher="Ubisoft" \
    year="2010" \
    media="download" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Steam/steamapps/common/r.u.s.e. demo/Ruse.exe"

load_ruse_demo_steam()
{
    w_steam_install_game 33310 "R.U.S.E."
}

#----------------------------------------------------------------

w_metadata supermeatboy_steam games \
    title="Super Meat Boy (Steam, non-free)" \
    publisher="Independent" \
    year="2010" \
    media="download" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Steam/steamapps/common/super meat boy/SuperMeatBoy.exe"

load_supermeatboy_steam()
{
    w_steam_install_game 40800 "Super Meat Boy"
}

#----------------------------------------------------------------

w_metadata trine_steam games \
    title="Trine (Steam)" \
    publisher="Frozenbyte" \
    year="2009" \
    media="download" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Steam/steamapps/common/trine/trine_launcher.exe"

load_trine_steam()
{
    w_steam_install_game 35700 "Trine"
}

#----------------------------------------------------------------

w_metadata trine_demo_steam games \
    title="Trine Demo (Steam)" \
    publisher="Frozenbyte" \
    year="2009" \
    media="download" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Steam/steamapps/common/trine demo/trine_launcher.exe"

load_trine_demo_steam()
{
    w_steam_install_game 35710 "Trine Demo"
}

#----------------------------------------------------------------

w_metadata wormsreloaded_demo_steam games \
    title="Worms Reloaded Demo (Steam)" \
    publisher="Team17" \
    year="2010" \
    media="download" \
    installed_exe1="$W_PROGRAMS_X86_WIN/Steam/steamapps/common/worms reloaded/WormsReloaded.exe"

load_wormsreloaded_demo_steam()
{
    w_steam_install_game 22690 "Worms Reloaded Demo"
}

#----------------------------------------------------------------
# Settings
#----------------------------------------------------------------
# Direct3D settings

winetricks_set_wined3d_var()
{
    # Filter out/correct bad or partial values
    # Confusing because dinput uses 'disable', but d3d uses 'disabled'
    # see wined3d_dll_init() in dlls/wined3d/wined3d_main.c
    # and DllMain() in dlls/ddraw/main.c
    case $2 in
    disable*) arg=disabled;;
    enable*) arg=enabled;;
    hard*) arg=hardware;;
    repack) arg=repack;;
    backbuffer|fbo|gdi|none|opengl|readdraw|readtex|texdraw|textex|auto) arg=$2;;
    [0-9]*) arg=$2;;
    *) w_die "illegal value $2 for $1";;
    esac

    echo "Setting Direct3D/$1 to $arg"
    cat > "$W_TMP"/set-wined3d.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\Direct3D]
"$1"="$arg"

_EOF_
    w_try_regedit "$W_TMP_WIN"\\set-wined3d.reg
}

#----------------------------------------------------------------

w_metadata glsl=enabled settings \
    title_uk="Включити GLSL шейдери (за замовчуванням)" \
    title="Enable GLSL shaders (default)"
w_metadata glsl=disabled settings \
    title_uk="Вимкнути GLSL шейдери та використовувати ARB шейдери (швидше, але іноді з перервами)" \
    title="Disable GLSL shaders, use ARB shaders (faster, but sometimes breaks)"

load_glsl()
{
    winetricks_set_wined3d_var UseGLSL $1
}

#----------------------------------------------------------------

w_metadata multisampling=enabled settings \
    title_uk="Включити Direct3D мультисемплінг" \
    title="Enable Direct3D multisampling"
w_metadata multisampling=disabled settings \
    title_uk="Вимкнути Direct3D мультисемплінг" \
    title="Disable Direct3D multisampling"

load_multisampling()
{
    winetricks_set_wined3d_var Multisampling $1
}

#----------------------------------------------------------------

w_metadata npm=repack settings \
    title_uk="Поставити NonPower2Mode на repack" \
    title="Set NonPower2Mode to repack"

load_npm()
{
    winetricks_set_wined3d_var NonPower2Mode $1
}

#----------------------------------------------------------------

w_metadata orm=fbo settings \
    title_uk="Поставити OffscreenRenderingMode=fbo (за замовчуванням)" \
    title="Set OffscreenRenderingMode=fbo (default)"
w_metadata orm=backbuffer settings \
    title_uk="Поставити OffscreenRenderingMode=backbuffer" \
    title="Set OffscreenRenderingMode=backbuffer"

load_orm()
{
    winetricks_set_wined3d_var OffscreenRenderingMode $1
}

#----------------------------------------------------------------

w_metadata strictdrawordering=enabled settings \
    title_uk="Включити StrictDrawOrdering" \
    title="Enable StrictDrawOrdering"
w_metadata strictdrawordering=disabled settings \
    title_uk="Вимкнути StrictDrawOrdering (за замовчуванням)" \
    title="Disable StrictDrawOrdering (default)"

load_strictdrawordering()
{
    winetricks_set_wined3d_var StrictDrawOrdering $1
}

#----------------------------------------------------------------

w_metadata rtlm=auto settings \
    title_uk="Поставити RenderTargetLockMode на авто (за замовчуванням)" \
    title="Set RenderTargetLockMode to auto (default)"
w_metadata rtlm=disabled settings \
    title_uk="Вимкнути RenderTargetLockMode" \
    title="Set RenderTargetLockMode to disabled"
w_metadata rtlm=readdraw settings \
    title_uk="Поставити RenderTargetLockMode на readdraw" \
    title="Set RenderTargetLockMode to readdraw"
w_metadata rtlm=readtex settings \
    title_uk="Поставити RenderTargetLockMode на readtex" \
    title="Set RenderTargetLockMode to readtex"
w_metadata rtlm=texdraw settings \
    title_uk="Поставити RenderTargetLockMode на texdraw" \
    title="Set RenderTargetLockMode to texdraw"
w_metadata rtlm=textex settings \
    title_uk="Поставити RenderTargetLockMode на textex" \
    title="Set RenderTargetLockMode to textex"

load_rtlm()
{
    winetricks_set_wined3d_var RenderTargetLockMode $1
}

#----------------------------------------------------------------
# AlwaysOffscreen settings

w_metadata ao=enabled settings \
    title_uk="Включити AlwaysOffscreen" \
    title="Enable AlwaysOffscreen"
w_metadata ao=disabled settings \
    title_uk="Вимкнути AlwaysOffscreen (за замовчуванням)" \
    title="Disable AlwaysOffscreen (default)"

load_ao()
{
    winetricks_set_wined3d_var AlwaysOffscreen $1
}

#----------------------------------------------------------------
# DirectDraw settings

w_metadata ddr=gdi settings \
    title_uk="Поставити DirectDrawRenderer на gdi" \
    title="Set DirectDrawRenderer to gdi"
w_metadata ddr=opengl settings \
    title_uk="Поставити DirectDrawRenderer на opengl" \
    title="Set DirectDrawRenderer to opengl"

load_ddr()
{
    winetricks_set_wined3d_var DirectDrawRenderer $1
}

#----------------------------------------------------------------
# DirectInput settings

w_metadata mwo=force settings \
    title_uk="Поставити примусове DirectInput MouseWarpOverride (необхідно для деяких ігор)" \
    title="Set DirectInput MouseWarpOverride to force (needed by some games)"
w_metadata mwo=enabled settings \
    title_uk="Включити DirectInput MouseWarpOverride (за замовчуванням)" \
    title="Set DirectInput MouseWarpOverride to enabled (default)"
w_metadata mwo=disable settings \
    title_uk="Вимкнути DirectInput MouseWarpOverride" \
    title="Set DirectInput MouseWarpOverride to disable"

load_mwo()
{
    # Filter out/correct bad or partial values
    # Confusing because dinput uses 'disable', but d3d uses 'disabled'
    # see alloc_device() in dlls/dinput/mouse.c
    case $1 in
    enable*) arg=enabled;;
    disable*) arg=disable;;
    force) arg=force;;
    *) w_die "illegal value $1 for MouseWarpOverride";;
    esac

    echo "Setting MouseWarpOverride to $arg"
    cat > "$W_TMP"/set-mwo.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\DirectInput]
"MouseWarpOverride"="$arg"

_EOF_
    w_try_regedit "$W_TMP"/set-mwo.reg
}

#----------------------------------------------------------------
# Mac Driver settings

w_metadata macdriver=mac settings \
    title_uk="Включити рідний Mac Quartz драйвер (за замовчуванням)" \
    title="Enable the Mac native Quartz driver (default)"
w_metadata macdriver=x11 settings \
    title_uk="Вимкнути рідний Mac Quartz драйвер та використовувати замість нього X11" \
    title="Disable the Mac native Quartz driver, use X11 instead"

load_macdriver()
{
    echo "Setting MacDriver to $arg"
    cat > "$W_TMP"/set-mac.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\Drivers]
"Graphics"="$arg"

_EOF_
    w_try_regedit "$W_TMP"/set-mac.reg
}

#----------------------------------------------------------------
# X11 Driver settings

w_metadata grabfullscreen=y settings \
    title_uk="Примусове захоплення курсору для повноекранних вікон (необхідно для деяких ігор)" \
    title="Force cursor clipping for full-screen windows (needed by some games)"
w_metadata grabfullscreen=n settings \
    title_uk="Вимкнути примусове захоплення курсору для повноекранних вікон (за замовчуванням)" \
    title="Disable cursor clipping for full-screen windows (default)"

load_grabfullscreen()
{
    case $1 in
    y|n) arg=$1;;
    *) w_die "illegal value $1 for GrabFullscreen";;
    esac

    echo "Setting GrabFullscreen to $arg"
    cat > "$W_TMP"/set-gfs.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"GrabFullscreen"="$arg"

_EOF_
    w_try_regedit "$W_TMP"/set-gfs.reg
}

w_metadata windowmanagerdecorated=y settings \
    title_uk="Дозволити менеджеру вікон декорувати вікна (за замовчуванням)" \
    title="Allow the window manager to decorate windows (default)"
w_metadata windowmanagerdecorated=n settings \
    title_uk="Не дозволяти менеджеру вікон декорувати вікна" \
    title="Prevent the window manager from decorating windows"

load_windowmanagerdecorated()
{
    case $1 in
    y|n) arg=$1;;
    *) w_die "illegal value $1 for Decorated";;
    esac

    echo "Setting Decorated to $arg"
    cat > "$W_TMP"/set-wmd.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"Decorated"="$arg"

_EOF_
    w_try_regedit "$W_TMP"/set-wmd.reg
}

w_metadata windowmanagermanaged=y settings \
    title_uk="Дозволити менеджеру вікон керування вікнами (за замовчуванням)" \
    title="Allow the window manager to control windows (default)"
w_metadata windowmanagermanaged=n settings \
    title_uk="Не дозволяти менеджеру вікон керування вікнами" \
    title="Prevent the window manager from controling windows"

load_windowmanagermanaged()
{
    case $1 in
    y|n) arg=$1;;
    *) w_die "illegal value $1 for Managed";;
    esac

    echo "Setting Managed to $arg"
    cat > "$W_TMP"/set-wmm.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"Managed"="$arg"

_EOF_
    w_try_regedit "$W_TMP"/set-wmm.reg
}

#----------------------------------------------------------------
# Other settings

#----------------------------------------------------------------

w_metadata alldlls=default settings \
    title_uk="Видалити всі перевизначення DLL" \
    title="Remove all DLL overrides"
w_metadata alldlls=builtin settings \
    title_uk="Перевизначити найбільш поширені DLL на вбудовані" \
    title="Override most common DLLs to builtin"

load_alldlls()
{
    case $1 in
    default) w_override_no_dlls ;;
    builtin) w_override_all_dlls ;;
    esac
}

w_metadata fontsmooth=disable settings \
    title_uk="Вимкнути згладжування шрифту" \
    title="Disable font smoothing"
w_metadata fontsmooth=bgr settings \
    title_uk="Включити субпіксельне згладжування шрифту для BGR LCD моніторів" \
    title="Enable subpixel font smoothing for BGR LCDs"
w_metadata fontsmooth=rgb settings \
    title_uk="Включити субпіксельне згладжування шрифту для RGB LCD моніторів" \
    title="Enable subpixel font smoothing for RGB LCDs"
w_metadata fontsmooth=gray settings \
    title_uk="Включити субпіксельне згладжування шрифту" \
    title="Enable subpixel font smoothing"

load_fontsmooth()
{
    case $1 in
    disable)   FontSmoothing=0; FontSmoothingOrientation=1; FontSmoothingType=0;;
    gray|grey) FontSmoothing=2; FontSmoothingOrientation=1; FontSmoothingType=1;;
    bgr)       FontSmoothing=2; FontSmoothingOrientation=0; FontSmoothingType=2;;
    rgb)       FontSmoothing=2; FontSmoothingOrientation=1; FontSmoothingType=2;;
    *) w_die "unknown font smoothing type $1";;
    esac

    echo "Setting font smoothing to $1"

    cat > "$W_TMP"/fontsmooth.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Control Panel\Desktop]
"FontSmoothing"="$FontSmoothing"
"FontSmoothingGamma"=dword:00000578
"FontSmoothingOrientation"=dword:0000000$FontSmoothingOrientation
"FontSmoothingType"=dword:0000000$FontSmoothingType

_EOF_
    w_try_regedit "$W_TMP_WIN"\\fontsmooth.reg
}

#----------------------------------------------------------------

w_metadata forcemono settings \
    title_uk="Примусове використання mono замість .NET (для налогодження)" \
    title="Force using Mono instead of .NET (for debugging)"

load_forcemono()
{
    w_override_dlls native mscoree
    w_override_dlls disabled mscorsvw.exe
}

#----------------------------------------------------------------

w_metadata gsm=0 settings \
    title="Set MaxShaderModelGS to 0"
w_metadata gsm=1 settings \
    title="Set MaxShaderModelGS to 1"
w_metadata gsm=2 settings \
    title="Set MaxShaderModelGS to 2"
w_metadata gsm=3 settings \
    title="Set MaxShaderModelGS to 3"

load_gsm()
{
    winetricks_set_wined3d_var MaxShaderModelGS $1
}

#----------------------------------------------------------------

w_metadata heapcheck settings \
    title_uk="Включити накопичувальну перевірку GlobalFlag" \
    title="Enable heap checking with GlobalFlag"

load_heapcheck()
{
    cat > "$W_TMP"/heapcheck.reg <<_EOF_
REGEDIT4

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager]
"GlobalFlag"=dword:00200030

_EOF_
    w_try_regedit "$W_TMP_WIN"\\heapcheck.reg
}

#----------------------------------------------------------------

w_metadata hidewineexports=enable settings \
    title="Enable hiding Wine exports from applications (wine-staging)"
w_metadata hidewineexports=disable settings \
    title="Disable hiding Wine exports from applications (wine-staging)"

load_hidewineexports()
{
    # Wine exports some functions allowing apps to query the Wine version and
    # information about the host environment. Using these functions, some apps
    # will intentionally terminate if they can detect that they are running in
    # a Wine environment.
    #
    # Hiding these Wine exports is only available in wine-staging.
    # See https://bugs.winehq.org/show_bug.cgi?id=38656
    case $arg in
        enable)
            local registry_value="\"Y\""
            ;;
        disable)
            local registry_value="-"
            ;;
        *) w_die "Unexpected argument, $arg";;
    esac

    cat > "$W_TMP"/set-wineexports.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine]
"HideWineExports"=$registry_value

_EOF_
    w_try_regedit "$W_TMP"/set-wineexports.reg
}

#----------------------------------------------------------------

w_metadata hosts settings \
    title_uk="Додати порожні файли у C:\windows\system32\drivers\etc\{hosts,services}" \
    title="Add empty C:\windows\system32\drivers\etc\{hosts,services} files"

load_hosts()
{
    # Create fake system32\drivers\etc\hosts and system32\drivers\etc\services files.
    # The hosts file is used to map network names to IP addresses without DNS.
    # The services file is used map service names to network ports.
    # Some apps depend on these files, but they're not implemented in Wine.
    # Fortunately, empty files in the correct location satisfy those apps.
    # See http://bugs.winehq.org/show_bug.cgi?id=12076

    # It's in system32 for both win32/win64
    mkdir -p "$W_WINDIR_UNIX"/system32/drivers/etc
    touch "$W_WINDIR_UNIX"/system32/drivers/etc/hosts
    touch "$W_WINDIR_UNIX"/system32/drivers/etc/services
}

#----------------------------------------------------------------

w_metadata native_mdac settings \
    title_uk="Перевизначити odbc32, odbccp32 та oledb32" \
    title="Override odbc32, odbccp32 and oledb32"

load_native_mdac()
{
    # Set those overrides globally so user programs get MDAC's ODBC
    # instead of Wine's unixodbc
    w_override_dlls native,builtin odbc32 odbccp32 oledb32
}

#----------------------------------------------------------------

w_metadata native_oleaut32 settings \
    title_uk="Перевизначити oleaut32" \
    title="Override oleaut32"

load_native_oleaut32()
{
    w_override_dlls native,builtin oleaut32
}

#----------------------------------------------------------------

w_metadata nocrashdialog settings \
    title_uk="Вимкнути діалог про помилку" \
    title="Disable crash dialog"

load_nocrashdialog()
{
    echo "Disabling graphical crash dialog"
    cat > "$W_TMP"/crashdialog.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\WineDbg]
"ShowCrashDialog"=dword:00000000

_EOF_
    cd "$W_TMP"
    w_try_regedit crashdialog.reg
}

#----------------------------------------------------------------

w_metadata nt40 settings \
    title_uk="Поставити версію Windows NT 4.0" \
    title="Set windows version to Windows NT 4.0"

load_nt40()
{
    w_set_winver nt40
}

#----------------------------------------------------------------

w_metadata psm=0 settings \
    title="Set MaxShaderModelPS to 0"
w_metadata psm=1 settings \
    title="Set MaxShaderModelPS to 1"
w_metadata psm=2 settings \
    title="Set MaxShaderModelPS to 2"
w_metadata psm=3 settings \
    title="Set MaxShaderModelPS to 3"

load_psm()
{
    winetricks_set_wined3d_var MaxShaderModelPS $1
}

#----------------------------------------------------------------

w_metadata sandbox settings \
    title_uk="Пісочниця wineprefix - видалити посилання до HOME" \
    title="Sandbox the wineprefix - remove links to \$HOME"

load_sandbox()
{
    w_skip_windows sandbox && return

    # Unmap drive Z
    rm -f "$WINEPREFIX/dosdevices/z:"

    _olddir="`pwd`"
    cd "$WINEPREFIX/drive_c/users/$USER"
    for x in *
    do
        if test -h "$x" && test -d "$x"
        then
            rm -f "$x"
            mkdir -p "$x"
        fi
    done
    cd "$_olddir"
    unset _olddir

    # Disable unixfs
    # Unfortunately, when you run with a different version of Wine, Wine will recreate this key.
    # See http://bugs.winehq.org/show_bug.cgi?id=22450
    "$WINE" regedit /d 'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\Namespace\{9D20AAE8-0625-44B0-9CA7-71889C2254D9}'

    # Disable recreation of the above key - or any updating of the registry - when running with a newer version of Wine.
    echo disable > "$WINEPREFIX/.update-timestamp"
}

#----------------------------------------------------------------

w_metadata sound=alsa settings \
    title_uk="Поставити звуковий драйвер ALSA" \
    title="Set sound driver to ALSA"
w_metadata sound=coreaudio settings \
    title_uk="Поставити звуковий драйвер Mac CoreAudio" \
    title="Set sound driver to Mac CoreAudio"
w_metadata sound=disabled settings \
    title_uk="Вимкнути звуковий драйвер" \
    title="Set sound driver to disabled"
w_metadata sound=oss settings \
    title_uk="Поставити звуковий драйвер OSS" \
    title="Set sound driver to OSS"
w_metadata sound=pulse settings \
    title_uk="Поставити звуковий драйвер PulseAudio" \
    title="Set sound driver to PulseAudio"

load_sound()
{
    echo "Setting sound driver to $1"
    cat > "$W_TMP"/set-sound.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\Drivers]
"Audio"="$1"

_EOF_
    w_try_regedit "$W_TMP_WIN"\\set-sound.reg
}

#----------------------------------------------------------------

w_metadata vd=off settings \
    title_uk="Вимкнути віртуальний робочий стіл" \
    title="Disable virtual desktop"
w_metadata vd=640x480 settings \
    title_uk="Включити віртуальний робочий стіл та поставити розмір 640x480" \
    title="Enable virtual desktop, set size to 640x480"
w_metadata vd=800x600 settings \
    title_uk="Включити віртуальний робочий стіл та поставити розмір 800x600" \
    title="Enable virtual desktop, set size to 800x600"
w_metadata vd=1024x768 settings \
    title_uk="Включити віртуальний робочий стіл та поставити розмір 1024x768" \
    title="Enable virtual desktop, set size to 1024x768"
w_metadata vd=1280x1024 settings \
    title_uk="Включити віртуальний робочий стіл та поставити розмір 1280x1024" \
    title="Enable virtual desktop, set size to 1280x1024"
w_metadata vd=1440x900 settings \
    title_uk="Включити віртуальний робочий стіл та поставити розмір 1440x900" \
    title="Enable virtual desktop, set size to 1440x900"

load_vd()
{
    size=$1
    case $size in
    off|disabled)
        cat > "$W_TMP"/vd.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\Explorer]
"Desktop"=-
[HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops]
"Default"=-

_EOF_
        ;;
    [1-9]*x[1-9]*)
        cat > "$W_TMP"/vd.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\Explorer]
"Desktop"="Default"
[HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops]
"Default"="$size"

_EOF_
        ;;
    *)
        w_die "you want a virtual desktop of $size?  I don't understand."
        ;;
    esac
    w_try_regedit "$W_TMP_WIN"/vd.reg
}

#----------------------------------------------------------------

w_metadata videomemorysize=default settings \
    title_uk="Дати можливість Wine визначити розмір відеопам'яті" \
    title="Let Wine detect amount of video card memory"
w_metadata videomemorysize=512 settings \
    title_uk="Повідомити Wine про 512МБ відеопам'яті" \
    title="Tell Wine your video card has 512MB RAM"
w_metadata videomemorysize=1024 settings \
    title_uk="Повідомити Wine про 1024МБ відеопам'яті" \
    title="Tell Wine your video card has 1024MB RAM"
w_metadata videomemorysize=2048 settings \
    title_uk="Повідомити Wine про 2048МБ відеопам'яті" \
    title="Tell Wine your video card has 2048MB RAM"

load_videomemorysize()
{
    size=$1
    echo "Setting video memory size to $size"

    case $size in
    default)

    cat > "$W_TMP"/set-video.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\Direct3D]
"VideoMemorySize"=-

_EOF_
    ;;
    *)
    cat > "$W_TMP"/set-video.reg <<_EOF_
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\Direct3D]
"VideoMemorySize"="$size"

_EOF_
    esac
    w_try_regedit "$W_TMP_WIN"\\set-video.reg
}

#----------------------------------------------------------------

w_metadata vista settings \
    title_uk="Поставити версію Windows Vista" \
    title="Set Windows version to Windows Vista"

load_vista()
{
    w_set_winver vista
}

#----------------------------------------------------------------

w_metadata vsm=0 settings \
    title="Set MaxShaderModelVS to 0"
w_metadata vsm=1 settings \
    title="Set MaxShaderModelVS to 1"
w_metadata vsm=2 settings \
    title="Set MaxShaderModelVS to 2"
w_metadata vsm=3 settings \
    title="Set MaxShaderModelVS to 3"

load_vsm()
{
    winetricks_set_wined3d_var MaxShaderModelVS $1
}

#----------------------------------------------------------------

w_metadata win2k settings \
    title_uk="Поставити версію Windows 2000" \
    title="Set Windows version to Windows 2000"

load_win2k()
{
    w_set_winver win2k
}

#----------------------------------------------------------------

w_metadata win2k3 settings \
    title_uk="Поставити версію Windows 2003" \
    title="Set Windows version to Windows 2003"

load_win2k3()
{
    w_set_winver win2k3
}

#----------------------------------------------------------------

w_metadata win31 settings \
    title_uk="Поставити версію Windows 3.1" \
    title="Set Windows version to Windows 3.1"

load_win31()
{
    w_set_winver win31
}

#----------------------------------------------------------------

w_metadata win7 settings \
    title_uk="Поставити версію Windows 7" \
    title="Set Windows version to Windows 7"

load_win7()
{
    w_set_winver win7
}

#----------------------------------------------------------------

w_metadata win95 settings \
    title_uk="Поставити версію Windows 95" \
    title="Set Windows version to Windows 95"

load_win95()
{
    w_set_winver win95
}

#----------------------------------------------------------------

w_metadata win98 settings \
    title_uk="Поставити версію Windows 98" \
    title="Set Windows version to Windows 98"

load_win98()
{
    w_set_winver win98
}

#----------------------------------------------------------------

# Really, we should support other values, since winetricks did
w_metadata winver= settings \
    title_uk="Поставити версію Windows за замовчуванням (winxp)" \
    title="Set Windows version to default (winxp)"

load_winver()
{
    w_set_winver winxp
}

#----------------------------------------------------------------

w_metadata winxp settings \
    title_uk="Поставити версію Windows XP" \
    title="Set Windows version to Windows XP"

load_winxp()
{
    w_set_winver winxp
}

#----------------------------------------------------------------

#---- Derived Metadata ----
# Generated automatically by measuring time and space requirements of all verbs
# size_MB includes size of virgin wineprefix, but not the cached installer
case $WINETRICKS_OPT_VERBOSE in
    2) set -x ;;
    *) set +x ;;
esac

for data in \
    3dmark03:size_MB=895,time_sec=149 \
    3dmark05:size_MB=1255,time_sec=208 \
    3dmark06:size_MB=2627,time_sec=461 \
    3dmark2000:size_MB=165,time_sec=71 \
    3dmark2001:size_MB=260,time_sec=141 \
    7zip:size_MB=53,time_sec=9 \
    abiword:size_MB=119,time_sec=15 \
    adobeair:size_MB=132,time_sec=8 \
    algodoo_demo:size_MB=165,time_sec=52 \
    allcodecs:size_MB=48,time_sec=3 \
    allfonts:size_MB=132,time_sec=114 \
    amstream:size_MB=48,time_sec=2 \
    aoe3_demo:size_MB=4472,time_sec=422 \
    aoe_demo:size_MB=164,time_sec=35 \
    art2kmin:size_MB=363,time_sec=36 \
    atmlib:size_MB=454,time_sec=73 \
    autohotkey:size_MB=53,time_sec=4 \
    baekmuk:size_MB=138,time_sec=3 \
    bioshock_demo:size_MB=7510,time_sec=1543 \
    bladekitten_demo:size_MB=1444,time_sec=174 \
    cjkfonts:size_MB=48,time_sec=4 \
    cmake:size_MB=85,time_sec=8 \
    cnc3_demo:size_MB=5244,time_sec=1022 \
    cod4mw_demo:size_MB=5730,time_sec=1108 \
    cod_demo:size_MB=574,time_sec=115 \
    colorprofile:size_MB=47,time_sec=1 \
    comctl32:size_MB=49,time_sec=1 \
    comdlg32ocx:size_MB=49,time_sec=1 \
    controlpad:size_MB=69,time_sec=4 \
    corefonts:size_MB=62,time_sec=2 \
    crypt32:size_MB=178,time_sec=71 \
    crysis2:size_MB=8259,time_sec=1200 \
    crysis2_demo_mp:size_MB=5259,time_sec=1473 \
    d3dcompiler_43:size_MB=138,time_sec=51 \
    d3dx10:size_MB=50,time_sec=4 \
    d3dx11_43:size_MB=48,time_sec=1 \
    d3dx9:size_MB=126,time_sec=3 \
    d3dx9_26:size_MB=48,time_sec=2 \
    d3dx9_28:size_MB=48,time_sec=1 \
    d3dx9_31:size_MB=48,time_sec=2 \
    d3dx9_35:size_MB=50,time_sec=2 \
    d3dx9_36:size_MB=48,time_sec=1 \
    d3dx9_42:size_MB=48,time_sec=1 \
    d3dxof:size_MB=48,time_sec=2 \
    dc2ba_demo:size_MB=209,time_sec=38 \
    deadspace2:size_MB=12693,time_sec=720 \
    devenum:size_MB=59,time_sec=2 \
    diablo2:size_MB=2577,time_sec=37 \
    dinput:size_MB=48,time_sec=1 \
    dinput8:size_MB=61,time_sec=2 \
    dirac:size_MB=50,time_sec=4 \
    directmusic:size_MB=63,time_sec=4 \
    directplay:size_MB=61,time_sec=3 \
    directx9:size_MB=387,time_sec=12 \
    dirt2_demo:size_MB=6241,time_sec=977 \
    divinity2_demo:size_MB=2906,time_sec=2627 \
    dmsynth:size_MB=57,time_sec=2 \
    dotnet11:size_MB=94,time_sec=15 \
    dotnet20:size_MB=360,time_sec=64 \
    dotnet30:size_MB=645,time_sec=302 \
    dotnet35:size_MB=1149,time_sec=445 \
    dragonage:size_MB=23771,time_sec=673 \
    dragonage2_demo:size_MB=4014,time_sec=1428 \
    droid:size_MB=63,time_sec=8 \
    dsound:size_MB=48,time_sec=1 \
    dxdiag:size_MB=75,time_sec=6 \
    dxdiagn:size_MB=48,time_sec=1 \
    eufonts:size_MB=58,time_sec=2 \
    eve:size_MB=5313,time_sec=1568 \
    eve:size_MB=11215,time_sec=467 \
    farmsim2011_demo:size_MB=48,time_sec=4 \
    ffdshow:size_MB=53,time_sec=4 \
    fifa11_demo:size_MB=4932,time_sec=845 \
    flash:size_MB=57,time_sec=3 \
    fontfix:size_MB=47,time_sec=0 \
    fontxplorer:size_MB=51,time_sec=5 \
    gdiplus:size_MB=50,time_sec=2 \
    gfw:size_MB=211,time_sec=11 \
    glut:size_MB=47,time_sec=1 \
    gothic4_demo:size_MB=7719,time_sec=1402 \
    guildwars:size_MB=224,time_sec=392 \
    hegemony_demo:size_MB=1927,time_sec=315 \
    hegemonygold_demo:size_MB=2339,time_sec=247 \
    hon:size_MB=1536,time_sec=337 \
    hphbp_demo:size_MB=2898,time_sec=556 \
    icodecs:size_MB=60,time_sec=29 \
    ie6:size_MB=340,time_sec=58 \
    ie7:size_MB=181,time_sec=44 \
    ie8:size_MB=202,time_sec=39 \
    imvu:size_MB=194,time_sec=17 \
    jet40:size_MB=54,time_sec=3 \
    l3codecx:size_MB=60,time_sec=5 \
    lhp_demo:size_MB=3200,time_sec=645 \
    liberation:size_MB=50,time_sec=3 \
    lucida:size_MB=51,time_sec=1 \
    masseffect2_demo:size_MB=8291,time_sec=1397 \
    mb_warband_demo:size_MB=1495,time_sec=35 \
    mdac25:size_MB=97,time_sec=6 \
    mdac27:size_MB=70,time_sec=3 \
    mdac28:size_MB=75,time_sec=4 \
    mfc40:size_MB=48,time_sec=0 \
    mfc42:size_MB=47,time_sec=1 \
    mingw:size_MB=132,time_sec=3 \
    mozillabuild:size_MB=891,time_sec=26 \
    mpc:size_MB=87,time_sec=2 \
    msasn1:size_MB=178,time_sec=3 \
    mshflxgd:size_MB=47,time_sec=0 \
    msi2:size_MB=62,time_sec=4 \
    msls31:size_MB=48,time_sec=0 \
    msmask:size_MB=47,time_sec=0 \
    mspaint:size_MB=49,time_sec=0 \
    msscript:size_MB=48,time_sec=0 \
    msxml3:size_MB=49,time_sec=1 \
    msxml4:size_MB=55,time_sec=0 \
    msxml6:size_MB=54,time_sec=1 \
    nfsshift_demo:size_MB=4877,time_sec=157 \
    ogg:size_MB=54,time_sec=1 \
    opensymbol:size_MB=49,time_sec=1 \
    openwatcom:size_MB=274,time_sec=12 \
    osmos_demo:size_MB=67,time_sec=5 \
    pdh:size_MB=48,time_sec=0 \
    penpenxmas:size_MB=49,time_sec=6 \
    physx:size_MB=213,time_sec=5 \
    plantsvszombies:size_MB=156,time_sec=24 \
    pngfilt:size_MB=49,time_sec=0 \
    puzzleagent_demo:size_MB=495,time_sec=36 \
    python26:size_MB=160,time_sec=9 \
    quartz:size_MB=62,time_sec=3 \
    quicktime72:size_MB=219,time_sec=9 \
    quicktime76:size_MB=237,time_sec=6 \
    rayman2_demo:size_MB=239,time_sec=146 \
    riched20:size_MB=49,time_sec=0 \
    riched30:size_MB=48,time_sec=0 \
    richtx32:size_MB=48,time_sec=0 \
    safari:size_MB=210,time_sec=4 \
    sammax301_demo:size_MB=1419,time_sec=341 \
    sammax304_demo:size_MB=1642,time_sec=88 \
    secondlife:size_MB=266,time_sec=24 \
    secur32:size_MB=47,time_sec=0 \
    shockwave:size_MB=134,time_sec=6 \
    sims3:size_MB=12884,time_sec=584 \
    sketchup:size_MB=319,time_sec=15 \
    spotify:size_MB=59,time_sec=4 \
    starcraft2_demo:size_MB=5241,time_sec=211 \
    tahoma:size_MB=48,time_sec=0 \
    takao:size_MB=176,time_sec=3 \
    tmnationsforever:size_MB=1871,time_sec=116 \
    uff:size_MB=47,time_sec=0 \
    unifont:size_MB=51,time_sec=0 \
    usp10:size_MB=50,time_sec=0 \
    ut3:size_MB=7355,time_sec=426 \
    utorrent:size_MB=48,time_sec=1 \
    vb2run:size_MB=48,time_sec=0 \
    vb3run:size_MB=47,time_sec=0 \
    vb4run:size_MB=49,time_sec=0 \
    vb5run:size_MB=49,time_sec=0 \
    vb6run:size_MB=50,time_sec=1 \
    vc2005express:size_MB=1614,time_sec=173 \
    vc2005trial:size_MB=7156,time_sec=53 \
    vcrun2003:size_MB=47,time_sec=0 \
    vcrun2005:size_MB=60,time_sec=2 \
    vcrun2008:size_MB=60,time_sec=2 \
    vcrun2010:size_MB=71,time_sec=7 \
    vcrun6:size_MB=51,time_sec=0 \
    vcrun6sp6:size_MB=109,time_sec=2 \
    vjrun20:size_MB=319,time_sec=57 \
    vlc:size_MB=221,time_sec=7 \
    wenquanyi:size_MB=50,time_sec=0 \
    windowscodecs:size_MB=53,time_sec=2 \
    winhttp:size_MB=49,time_sec=0 \
    wininet:size_MB=47,time_sec=0 \
    wme9:size_MB=136,time_sec=5 \
    wmi:size_MB=62,time_sec=12 \
    wmp10:size_MB=161,time_sec=7 \
    wmp9:size_MB=143,time_sec=12 \
    wog:size_MB=124,time_sec=5 \
    wsh56js:size_MB=45,time_sec=0 \
    xact:size_MB=60,time_sec=6 \
    xinput:size_MB=47,time_sec=2 \
    xmllite:size_MB=50,time_sec=4 \
    xvid:size_MB=54,time_sec=2 \
    zootycoon2_demo:size_MB=299,time_sec=32 \

do
    cmd=${data%%:*}
    file="`echo "$WINETRICKS_METADATA"/*/$cmd.vars`"
    if test -f "$file"
    then
        case $data in
        *size_MB*)
            size_MB=${data##*size_MB=}       # remove anything before value
            size_MB=${size_MB%%,*}           # remove anything after value
            echo size_MB=$size_MB >> "$file"
            ;;
        esac

        case $data in
        *time_sec*)
            time_sec=${data##*time_sec=}
            time_sec=${time_sec%%,*}
            echo time_sec=$time_sec >> "$file"
        esac
    fi
    unset size_MB time_sec
done

# Restore verbosity:
case $WINETRICKS_OPT_VERBOSE in
    1|2) set -x ;;
    *) set +x ;;
esac

#---- Main Program ----

winetricks_stats_save()
{
    # Save opt-in status
    if test "$WINETRICKS_STATS_REPORT"
    then
        echo "$WINETRICKS_STATS_REPORT" > "$W_CACHE"/track_usage
    fi
}

winetricks_stats_init()
{
    # Load opt-in status if not already set by a command-line option
    if test ! "$WINETRICKS_STATS_REPORT" && test -f "$W_CACHE"/track_usage
    then
        WINETRICKS_STATS_REPORT=`cat "$W_CACHE"/track_usage`
    fi

    if test ! "$WINETRICKS_STATS_REPORT"
    then
        # No opt-in status found.  If GUI active, ask user whether they would like to opt in.
        case $WINETRICKS_GUI in
        zenity)
            case $LANG in
            de*)
                title="Einmalige Frage zur Hilfe an der Winetricks Entwicklung"
                question="Möchten Sie die Winetricks Entwicklung unterstützen indem Sie Winetricks Statistiken übermitteln lassen?  Sie können die Übermittlung jederzeit mit 'winetricks --optout' ausschalten"
                thanks="Danke! Sie bekommen diese Frage nicht mehr gestellt.  Sie können die Übermittlung jederzeit mit 'winetricks --optout' wieder ausschalten"
                declined="OK, Winetricks wird *keine* Statistiken übermitteln.  Sie bekommen diese Frage nicht mehr gestellt."
                ;;
            *)
                title="One-time question about helping Winetricks development"
                question="Would you like to help winetricks development by letting winetricks report statistics?  You can turn reporting off at any time with the command 'winetricks --optout'"
                thanks="Thanks!  You won't be asked this question again.  Remember, you can turn reporting off at any time with the command 'winetricks --optout'"
                declined="OK, winetricks will *not* report statistics.  You won't be asked this question again."
                ;;
            esac
            if $WINETRICKS_GUI --question --text "$question" --title "$title"
            then
                $WINETRICKS_GUI --info --text "$thanks"
                WINETRICKS_STATS_REPORT=1
            else
                $WINETRICKS_GUI --info --text "$declined"
                WINETRICKS_STATS_REPORT=0
            fi
            echo $WINETRICKS_STATS_REPORT > "$W_CACHE"/track_usage
            ;;
        esac
    fi
    winetricks_stats_save
}

# Retrieve a short string with the operating system name and version
winetricks_os_description()
{
    (
    case "$OS" in
    "Windows_NT")
        echo windows ;;
    *)  echo "$WINETRICKS_WINE_VERSION" ;;
    esac
    ) | tr '\012' ' '
}

winetricks_stats_report()
{
    # If user has opted in to usage tracking, report what he used (if anything)
    case "$WINETRICKS_STATS_REPORT" in
    1) ;;
    *) return;;
    esac
    test -f "$WINETRICKS_WORKDIR"/breadcrumbs || return

    WINETRICKS_STATS_BREADCRUMBS=`cat "$WINETRICKS_WORKDIR"/breadcrumbs | tr '\012' ' '`
    echo "You opted in, so reporting '$WINETRICKS_STATS_BREADCRUMBS' to the winetricks maintainer so he knows which winetricks verbs get used and which don't.  Use --optout to disable future reports."

    report="os=`winetricks_os_description`&winetricks=$WINETRICKS_VERSION&breadcrumbs=$WINETRICKS_STATS_BREADCRUMBS"
    report="`echo $report | sed 's/ /%20/g'`"
    # Just do a HEAD request with the raw command line.
    # Yes, this can be fooled by caches.  That's ok.
    if [ -x "`which wget 2>/dev/null`" ]
    then
        wget --spider "http://kegel.com/data/winetricks-usage?$report" > /dev/null 2>&1 || true
    elif [ -x "`which curl 2>/dev/null`" ]
    then
        curl -I "http://kegel.com/data/winetricks-usage?$report" > /dev/null 2>&1 || true
    fi
}

winetricks_stats_log_command()
{
    # log what we execute for possible later statistics reporting
    echo "$*" >> "$WINETRICKS_WORKDIR"/breadcrumbs

    # and for the user's own reference later, when figuring out what he did
    case "$OS" in
    "Windows_NT") _W_LOGDIR="$W_WINDIR_UNIX"/Temp ;;
    *) _W_LOGDIR="$WINEPREFIX" ;;
    esac
    mkdir -p "$_W_LOGDIR"
    echo "$*" >> "$_W_LOGDIR"/winetricks.log
    unset _W_LOGDIR
}

# Launch a new terminal window if in GUI, or
# spawn a shell in the current window if command line.
# New shell contains proper WINEPREFIX and WINE environment variables.
# May be useful when debugging verbs.
winetricks_shell()
{
    (
    cd "$W_DRIVE_C"
    export WINE

    case $WINETRICKS_GUI in
    none)
        $SHELL
        ;;
    *)
        for term in gnome-terminal konsole Terminal xterm
        do
            if test `which $term` 2> /dev/null
            then
                $term
                break
            fi
        done
        ;;
    esac
    )
}

# Usage: execute_command verb[=argument]
execute_command()
{
    case "$1" in
    *=*) arg=`echo $1 | sed 's/.*=//'`; cmd=`echo $1 | sed 's/=.*//'`;;
    *) cmd="$1"; arg="" ;;
    esac

    case "$1" in

    # FIXME: avoid duplicated code
    apps|benchmarks|dlls|fonts|games|prefix|settings)
        WINETRICKS_CURMENU=$1
        ;;

    # Late options
    -*)
        if ! winetricks_handle_option $1
        then
            winetricks_usage
            exit 1
        fi
        ;;

    # Hard-coded verbs
    main) WINETRICKS_CURMENU=main ;;
    help) w_open_webpage https://code.google.com/archive/p/winetricks/wikis ;;
    list) winetricks_list_all ;;
    list-cached) winetricks_list_cached ;;
    list-download) winetricks_list_download ;;
    list-manual-download) winetricks_list_manual_download ;;
    list-installed) winetricks_list_installed ;;
    list-all)
        old_menu="$WINETRICKS_CURMENU"
        for WINETRICKS_CURMENU in apps benchmarks dlls fonts games prefix settings
        do
            echo "===== $WINETRICKS_CURMENU ====="
            winetricks_list_all
        done
        WINETRICKS_CURMENU="$old_menu"
        ;;
    unattended) winetricks_set_unattended 1 ;;
    attended) winetricks_set_unattended 0 ;;
    showbroken) W_OPT_SHOWBROKEN=1 ;;
    hidebroken) W_OPT_SHOWBROKEN=0 ;;
    prefix=*) winetricks_set_wineprefix "$arg" ;;
    annihilate) winetricks_annihilate_wineprefix ;;
    folder) w_open_folder "$WINEPREFIX" ;;
    winecfg) "$WINE" winecfg ;;
    regedit) "$WINE" regedit ;;
    taskmgr) "$WINE" taskmgr & ;;
    uninstaller) "$WINE" uninstaller ;;
    shell) winetricks_shell ;;

    # These have to come before *=disabled to avoid looking like DLLs
    fontsmooth=disable*) w_call fontsmooth=disable ;;
    glsl=disable*) w_call glsl=disabled ;;
    multisampling=disable*) w_call multisampling=disabled ;;
    mwo=disable*) w_call mwo=disable ;;   # FIXME: relax matching so we can handle these spelling differences in verb instead of here
    rtlm=disable*) w_call rtlm=disabled ;;
    sound=disable*) w_call sound=disabled ;;
    ao=disable*) w_call ao=disabled ;;
    strictdrawordering=disable*) w_call strictdrawordering=disabled ;;

    # Use winecfg if you want a GUI for plain old DLL overrides
    alldlls=*) w_call $1 ;;
    *=native) w_do_call native $cmd;;
    *=builtin) w_do_call builtin $cmd;;
    *=default) w_do_call default $cmd;;
    *=disabled) w_do_call disabled $cmd;;
    vd=*) w_do_call $cmd;;

    # Hacks for backwards compatibility
    cc580) w_call comctl32 ;;
    comdlg32.ocx) w_call comdlg32ocx ;;
    dotnet1) w_call dotnet11 ;;
    dotnet2) w_call dotnet20 ;;
    flash11) w_call flash ;;
    fm20) w_call controlpad ;;   # art2kmin also comes with fm20.dll
    fontsmooth-bgr) w_call fontsmooth=bgr ;;
    fontsmooth-disable) w_call fontsmooth=disable ;;
    fontsmooth-gray) w_call fontsmooth=gray ;;
    fontsmooth-rgb) w_call fontsmooth=rgb ;;
    glsl-disable) w_call glsl=disabled ;;
    glsl-enable) w_call glsl=enabled ;;
    ie6_full) w_call ie6 ;;
    jscript) w_call wsh56js ;;            # FIXME: use wsh57 instead?
    npm-repack) w_call npm=repack ;;
    oss) w_call sound=oss ;;
    python) w_call python26 ;;
    vbrun60) w_call vb6run ;;
    vcrun2005sp1) w_call vcrun2005 ;;
    vcrun2008sp1) w_call vcrun2008 ;;
    wsh56) w_call wsh57 ;;
    xlive) w_call gfw ;;

    # Normal verbs, with metadata and load_ functions
    *)
        if winetricks_metadata_exists $1
        then
            w_call "$1"
        else
            echo Unknown arg $1
            winetricks_usage
            exit 1
        fi
        ;;
    esac
}

if ! test "$WINETRICKS_LIB"
then
    # If user opted out, save that preference now.
    winetricks_stats_save

    # If user specifies menu on command line, execute that command, but don't commit to command-line mode
    # FIXME: this code is duplicated several times; unify it
    if echo "$WINETRICKS_CATEGORIES" | grep -w "$1" > /dev/null
    then
        WINETRICKS_CURMENU=$1
        shift
    fi

    case "$1" in
    die) w_die "we who are about to die salute you." ;;
    volnameof=*)
        # Debug code.  Remove later?
        # Since Linux's volname command can't handle DVDs, winetricks has its own,
        # implemented using dd, old gum, and some string I had laying around.
        # You can try it like this:
        #  winetricks volnameof=/dev/sr0
        # or
        #  winetricks volnameof=foo.iso
        # This will read the volname from the given image and put it to stdout.
        winetricks_volname ${1#volnameof=}
        ;;
    "")
        if test x"$DISPLAY" = x""
        then
            echo "DISPLAY not set, not defaulting to gui"
            winetricks_usage
            exit 0
        fi
        # GUI case
        # No non-option arguments given, so read them from GUI, and loop until user quits
        winetricks_detect_gui
        winetricks_detect_sudo
        while true
        do
            case $WINETRICKS_CURMENU in
            main) verbs=`winetricks_mainmenu` ;;
            prefix)
                verbs=`winetricks_prefixmenu`;
                # Cheezy hack: choosing 'attended' or 'unattended' leaves you in same menu
                case "$verbs" in
                attended) winetricks_set_unattended 0 ; continue;;
                unattended) winetricks_set_unattended 1 ; continue;;
                esac
                ;;
            settings) verbs=`winetricks_settings_menu` ;;
            *) verbs="`winetricks_showmenu`" ;;
            esac

            if test "$verbs" = ""
            then
                # "user didn't pick anything, back up a level in the menu"
                case "$WINETRICKS_CURMENU"-"$WINETRICKS_OPT_SHAREDPREFIX" in
                apps-0|benchmarks-0|games-0|main-*) WINETRICKS_CURMENU=prefix ;;
                prefix-*) break ;;
                *)    WINETRICKS_CURMENU=main ;;
                esac
            elif echo "$WINETRICKS_CATEGORIES" | grep -w "$verbs" > /dev/null
            then
                WINETRICKS_CURMENU=$verbs
            else
                winetricks_stats_init
                # Otherwise user picked one or more real verbs.
                case "$verbs" in
                prefix=*)
                    # prefix menu is special, it only returns one verb, and the
                    # verb can contain spaces
                    execute_command "$verbs"
                    # after picking a prefix, want to land in main.
                    WINETRICKS_CURMENU=main ;;
                *)
                    for verb in $verbs
                    do
                        execute_command "$verb"
                    done
                    case "$WINETRICKS_CURMENU"-"$WINETRICKS_OPT_SHAREDPREFIX" in
                    prefix-*|apps-0|benchmarks-0|games-0)
                        # After installing isolated app, return to prefix picker
                        WINETRICKS_CURMENU=prefix
                        ;;
                    *)
                        # Otherwise go to main menu.
                        WINETRICKS_CURMENU=main
                        ;;
                    esac
                    ;;
                esac
            fi
        done
        ;;
    *)
        winetricks_stats_init
        # Command-line case
        winetricks_detect_sudo
        # User gave command-line arguments, so just run those verbs and exit
        for verb
        do
            case $verb in
            *.verb)
                # Load the verb file
                case $verb in
                */*) . $verb ;;
                *) . ./$verb ;;
                esac
                # And forget that the verb comes from a file
                verb="`echo $verb | sed 's,.*/,,;s,.verb,,'`"
                ;;
            esac
            execute_command "$verb"
        done
        ;;

    esac

    winetricks_stats_report
fi
