#### Custom xterm ####
#a = black
#b = red
#c = green
#d = brown
#e = blue
#f = magenta
#g = cyan
#h = grey
#A = dark grey
#B = bold red
#C = bold green
#D = yellow
#E = bold blue
#F = magenta
#G = cyan
#H = white
#x = default

#1.directory
#2.symbolic link
#3.socket
#4.pipe
#5.executable
#6.block device
#7.character device
#8.executable with setuid set
#9.executable with setguid set
#10.directory writable by others, with sticky bit
#11.directory writable by others, without sticky bit

#export COLOR_NC='\e[0m' # No Color
#export COLOR_WHITE='\e[1;37m'
#export COLOR_BLACK='\e[0;30m'
#export COLOR_BLUE='\e[0;34m'
#export COLOR_LIGHT_BLUE='\e[1;34m'
#export COLOR_GREEN='\e[0;32m'
#export COLOR_LIGHT_GREEN='\e[1;32m'
#export COLOR_CYAN='\e[0;36m'
#export COLOR_LIGHT_CYAN='\e[1;36m'
#export COLOR_RED='\e[0;31m'
#export COLOR_LIGHT_RED='\e[1;31m'
#export COLOR_PURPLE='\e[0;35m'
#export COLOR_BROWN='\e[0;33m'
#export COLOR_YELLOW='\e[1;33m'
#export COLOR_GRAY='\e[0;30m'
#export COLOR_LIGHT_GRAY='\e[0;37m'
#### Text Attributes ####
export ATTR_NONE=00
export ATTR_BOLD=01
export ATTR_UNDERSCORE=04
export ATTR_BLINK=05
export ATTR_REVERSE=07
export ATTR_CONCEALED=08

#### Text Colors ####
export TXT_BLACK=30
export TXT_RED=31
export TXT_GREEN=32
export TXT_YELLOW=33
export TXT_BLUE=34
export TXT_MAGENTA=35
export TXT_CYAN=36
export TXT_WHITE=37

#### Background Colors ####
export BCKGRND_BLACK=40
export BCKGRND_RED=41
export BCKGRND_GREEN=42
export BCKGRND_YELLOW=43
export BCKGRND_BLUE=44
export BCKGRND_MAGENTA=45
export BCKGRND_CYAN=46
export BCKGRND_WHITE=47

#export TERM=xterm-color
#export GREP_OPTIONS='--color=auto' GREP_COLOR='1;32'
#export CLICOLOR=1
#export LSCOLORS=ExFxCxDxBxegedabagacad


#case $TERM in
#     xterm*|rxvt*)
#         local TITLEBAR='\[\033]0;\u ${NEW_PWD}\007\]'
#          ;;
#     *)
#         local TITLEBAR=""
#          ;;
#    esac

#local UC=$COLOR_WHITE               # user's color
#[ $UID -eq "0" ] && UC=$COLOR_RED   # root's color

#PS1="$TITLEBAR\n\[${UC}\]\u \[${COLOR_LIGHT_BLUE}\]\${PWD} \[${COLOR_BLACK}\]\$(vcprompt) \n\[${COLOR_LIGHT_GREEN}\]\[${COLOR_NC}\] "


#### TAKEN FROM WINDOWS GIT BASH ####
TITLEPREFIX='Bash Prompt (Ubuntu on Windows)'

PS1='\[\033]0;$TITLEPREFIX => ${PWD//[^[:ascii:]]/?}\007\]' # set window title
PS1="$PS1"'\n'                 # new line
PS1="$PS1"'\[\033[32m\]'       # change to green
PS1="$PS1"'\u@\h '             # user@host<space>
PS1="$PS1"'\[\033[35m\]'       # change to purple
#PS1="$PS1"'$MSYSTEM '          # show MSYSTEM
PS1="$PS1"'\[\033[33m\]'       # change to brownish yellow
PS1="$PS1"'\w'                 # current working directory
#if test -z "$WINELOADERNOEXEC"
#then
	#GIT_EXEC_PATH="$(git --exec-path 2>/dev/null)"
	#COMPLETION_PATH="${GIT_EXEC_PATH%/libexec/git-core}"
	#COMPLETION_PATH="${COMPLETION_PATH%/lib/git-core}"
	#COMPLETION_PATH="$COMPLETION_PATH/share/git/completion"
	#if test -f "$COMPLETION_PATH/git-prompt.sh"
	#then
	#	. "$COMPLETION_PATH/git-completion.bash"
	#	. "$COMPLETION_PATH/git-prompt.sh"
	#	PS1="$PS1"'\[\033[36m\]'  # change color to cyan
	#	PS1="$PS1"'`__git_ps1`'   # bash function
	#fi
#fi
PS1="$PS1"'\[\033[0m\]'        # change color
PS1="$PS1"'\n'                 # new line
PS1="$PS1"'$ '                 # prompt: always $
MSYS2_PS1="$PS1"               # for detection by MSYS2 SDK's bash.basrc

#LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:';
########################################

#TERM XTERM
#COLOR all
#NORMAL 00;37
#DIR 01;33
#FILE 00;36
#LINK 01;36
#ORPHAN undefined #default undefined
#MISSING undefined #default undefined
#FIFO 00;31 #default 31
#SOCK 33 #default 33
#DOOR #default ?
#BLK 44;37 #default 44;37
#CHR 44;37 #default 44;37
#EXEC 01;32 #default 35
#LEFTCODE \e[ #default \e[
#RIGHTCODE m #default m
#ENDCODE undefined #default undefined
#*extension
#.extension

#di = directory
#fi = file
#ln = symbolic link
#pi = fifo file
#so = socket file
#bd = block (buffered) special file
#cd = character (unbuffered) special file
#or = symbolic link pointing to a non-existent file (orphan)
#mi = non-existent file pointed to by a symbolic link (visible when you type ls -l)
#ex = file which is executable (ie. has 'x' set in permissions).
#*.rpm = files with the ending .rpm

export LS_COLORS='rs=0:di=01;36:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:su=37;41:sg=30;43:ca=30;41:tw=01;36:ow=01;36:st=37;44:ex=01;32:*.tar=01;33:*.tgz=01;33:*.arj=01;33:*.taz=01;33:*.lzh=01;33:*.lzma=01;33:*.tlz=01;33:*.txz=01;33:*.zip=01;33:*.z=01;33:*.Z=01;33:*.dz=01;33:*.gz=01;33:*.lz=01;33:*.xz=01;33:*.bz2=01;33:*.bz=01;33:*.tbz=01;33:*.tbz2=01;33:*.tz=01;33:*.deb=01;33:*.rpm=01;33:*.jar=01;33:*.war=01;33:*.ear=01;33:*.sar=01;33:*.rar=01;33:*.ace=01;33:*.zoo=01;33:*.cpio=01;33:*.7z=01;33:*.rz=01;33:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.axv=01;35:*.anx=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.axa=00;36:*.oga=00;36:*.spx=00;36:*.xspf=00;36:';
