# /etc/profile.d/complete.bash for SuSE Linux
#
#
# This feature has its own file because some other shells
# do not like the way how the bash assigns arrays
#
# REQUIRES bash 4.0 and higher
#

 _def="-o default -o bashdefault"
 _dir="-o nospace -o dirnames -o plusdirs"
_file="-o nospace -o dirnames"
_nosp="-o nospace"

# Escape file and directory names, add slash to directories if needed.
# Escaping could be done by the option 'filenames' but this fails
# e.g. on variable expansion like $HO<TAB>
_compreply_ ()
{
    local IFS=$'\n'
    local s x
    local -i o
    local -i isdir=$1

    test ${#COMPREPLY[@]} -eq 0 && return 0

    #
    # Append a slash on the real result, avoid annoying double tab
    #
    for ((o=0; o < ${#COMPREPLY[@]}; o++)) ; do
	if test ! -d "${COMPREPLY[$o]}" ; then
	    ((isdir == 0)) || continue
	    COMPREPLY[$o]="${COMPREPLY[$o]%%/}"
	    continue
	fi
	COMPREPLY[$o]="${COMPREPLY[$o]%%/}/"
    done

    #
    # Escape spaces and braces in path names with `\'
    #
    s="${COMP_WORDBREAKS//[: ]}"
    s="${s//	}"
    s="${s//[\{\}()\[\]]}"
    s="${s} 	(){}[]\`\$"
    o=${#s}

    while test $((o--)) -gt 0 ; do
	x="${s:${o}:1}"
	case "$x" in
	\() COMPREPLY=($(echo "${COMPREPLY[*]}"|command sed -r 's/\(/\\\(/g')) ;;
	*)  COMPREPLY=(${COMPREPLY[*]//${x}/\\${x}}) ;;
	esac
    done
}

# Expanding shell function for directories
_cd_ ()
{
    local c=${COMP_WORDS[COMP_CWORD]}
    local s g=0 x
    local IFS=$'\n'
    local -i o
    local -i isdir=0

    shopt -q extglob && g=1
    test $g -eq 0 && shopt -s extglob

    if [[ $COMP_WORDBREAKS =~ : && $COMP_LINE  =~ : ]] ; then
	# Do not use plusdirs as there is a colon in the directory
	# name(s) which will not work even if escaped with backslash.
	compopt +o plusdirs
	# Restore last argument without breaking at colon
	if ((COMP_CWORD > 1)) ; then
	    IFS="${COMP_WORDBREAKS//:}"
	    COMP_WORDS=($COMP_LINE)
	    let COMP_CWORD=${#COMP_WORDS[@]}-1
	    c=${COMP_WORDS[COMP_CWORD]}
	    IFS=$'\n'
	fi
    fi

    case "$(complete -p ${1##*/} 2> /dev/null)" in
    mkdir)  ;;
    *)	    s="-S/"
    esac

    case "$c" in
    *[*?[]*)	COMPREPLY=()				# use bashdefault
		test $g -eq 0 && shopt -u extglob
		return 0						;;
    \$\(*\))	eval COMPREPLY=\(${c}\) ;;
    \$\(*)	COMPREPLY=($(compgen -c -P '$(' -S ')'	-- ${c#??}))	;;
    \`*\`)	eval COMPREPLY=\(${c}\) ;;
    \`*)	COMPREPLY=($(compgen -c -P '\`' -S '\`' -- ${c#?}))	;;
    \$\{*\})	eval COMPREPLY=\(${c}\) ;;
    \$\{*)	COMPREPLY=($(compgen -v -P '${' -S '}'	-- ${c#??}))	;;
    \$*)	COMPREPLY=($(compgen -v -P '$' $s	-- ${c#?}))
		eval COMPREPLY=\(${COMPREPLY[@]}\)
		((${#COMPREPLY[@]} == 0)) || let isdir++		;;
    \~*/*)	COMPREPLY=($(compgen -d $s 		-- "${c}"))
		((${#COMPREPLY[@]} == 0)) || let isdir++		;;
    \~*)	COMPREPLY=($(compgen -u $s 		-- "${c}"))	;;
    *\:*)	if [[ $COMP_WORDBREAKS =~ : ]] ; then
		    x=${c%"${c##*[^\\]:}"}
		    COMPREPLY=($(compgen -d $s          -- "${c}"))
 		    COMPREPLY=(${COMPREPLY[@]#"$x"})
		    ((${#COMPREPLY[@]} == 0)) || let isdir++
		fi
		test $g -eq 0 && shopt -u extglob
		return 0						;;
    *)		COMPREPLY=()				# use (bash)default
		test $g -eq 0 && shopt -u extglob
		return 0						;;
    esac

    if test \( "${1##*/}" = "cd" -o "${1##*/}" = "pushd" \) -a ${#COMPREPLY[@]} -gt 0 ; then
	#
	# Handle the CDPATH variable
	#
	x="$(bind -v)"
	local dir=$([[ $x =~ mark-directories+([[:space:]])on ]] && echo on)
	local sym=$([[ $x =~ mark-symlinked-directories+([[:space:]])on ]] && echo on)

	for x in ${CDPATH//:/$'\n'}; do
	    o=${#COMPREPLY[@]}
	    for s in $(compgen -d $x/$c); do
		if [[ (($sym == on && -h $s) || ($dir == on && ! -h $s)) && ! -d ${s#$x/} ]] ; then
		    s="${s}/"
		fi
		COMPREPLY[o++]=${s#$x/}
	    done
	    ((${#COMPREPLY[@]} == 0)) || let isdir++
	done
    fi

    _compreply_ $isdir

    test $g -eq 0 && shopt -u extglob
    return 0
}

if shopt -q cdable_vars; then
    complete ${_def} ${_dir} -vF _cd_		cd
else
    complete ${_def} ${_dir}  -F _cd_		cd
fi
complete ${_def} ${_dir}  -F _cd_		rmdir pushd chroot chrootx
complete ${_def} ${_file} -F _cd_		mkdir

# General expanding shell function
_exp_ ()
{
    # bash `complete' is broken because you can not combine
    # -d, -f, and -X pattern without missing directories.
    local c=${COMP_WORDS[COMP_CWORD]}
    local a="${COMP_LINE}"
    local e s g=0 cd dc t=""
    local -i o
    local IFS

    shopt -q extglob && g=1
    test $g -eq 0 && shopt -s extglob
    # Don't be fooled by the bash parser if extglob is off by default
    cd='*-?(c)d*'
    dc='*-d?(c)*'

    case "${1##*/}" in
    compress)		e='*.Z'					;;
    bzip2)
	case "$c" in
	-)		COMPREPLY=(d c)
			test $g -eq 0 && shopt -u extglob
			return 0				;;
 	-?|-??)		COMPREPLY=($c)
			test $g -eq 0 && shopt -u extglob
			return 0				;;
	esac
	case "$a" in
	$cd|$dc)	e='!*.+(*)'
			t='@(bzip2 compressed)*'		;;
	*)		e='*.bz2'				;;
	esac							;;
    bunzip2)		e='!*.+(*)'
			t='@(bzip2 compressed)*'		;;
    gzip)
	case "$c" in
	-)		COMPREPLY=(d c)
			test $g -eq 0 && shopt -u extglob
			return 0				;;
 	-?|-??)		COMPREPLY=($c)
			test $g -eq 0 && shopt -u extglob
			return 0				;;
	esac
	case "$a" in
	$cd|$dc)	e='!*.+(*)'
			t='@(gzip compressed|*data 16 bits)*'	;;
	*)		e='*.+(gz|tgz|z|Z)'			;;
	esac							;;
    gunzip)		e='!*.+(*)'
			t='@(gzip compressed|*data 16 bits)*'	;;

    lzma)
	case "$c" in
	-)		COMPREPLY=(d c)
			test $g -eq 0 && shopt -u extglob
			return 0				;;
 	-?|-??)		COMPREPLY=($c)
			test $g -eq 0 && shopt -u extglob
			return 0				;;
	esac
	case "$a" in
	$cd|$dc)	e='!*.+(lzma)'				;;
	*)		e='*.+(lzma)'				;;
	esac							;;
    unlzma)		e='!*.+(lzma)'				;;
    xz)
	case "$c" in
	-)		COMPREPLY=(d c)
			test $g -eq 0 && shopt -u extglob
			return 0				;;
 	-?|-??)		COMPREPLY=($c)
			test $g -eq 0 && shopt -u extglob
			return 0				;;
	esac
	case "$a" in
	$cd|$dc)	e='!*.+(xz)'				;;
	*)		e='*.+(xz)'				;;
	esac							;;
    unxz)		e='!*.+(xz)'				;;
    uncompress)		e='!*.Z'				;;
    unzip)		e='!*.+(*)'
			t="@(MS-DOS executable|Zip archive)*"	;;
    gs|ghostview)	e='!*.+(eps|EPS|ps|PS|pdf|PDF)'		;;
    gv|kghostview)	e='!*.+(eps|EPS|ps|PS|ps.gz|pdf|PDF)'	;;
    acroread|[xk]pdf)	e='!*.+(fdf|pdf|FDF|PDF)'		;;
    evince)		e='!*.+(ps|PS|pdf|PDF)'                 ;;
    dvips)		e='!*.+(dvi|DVI)'			;;
    rpm|zypper)		e='!*.+(rpm|you)'			;;
    [xk]dvi)		e='!*.+(dvi|dvi.gz|DVI|DVI.gz)'		;;
    tex|latex|pdflatex)	e='!*.+(tex|TEX|texi|latex)'		;;
    export)
	case "$a" in
	*=*)		c=${c#*=}				;;
	*)		COMPREPLY=($(compgen -v -- ${c}))
			test $g -eq 0 && shopt -u extglob
			return 0				;;
	esac
	;;
    *)			e='!*'
    esac

    case "$(complete -p ${1##*/} 2> /dev/null)" in
	*-d*)	;;
	*) s="-S/"
    esac

    IFS=$'\n'
    case "$c" in
    \$\(*\))	   eval COMPREPLY=\(${c}\) ;;
    \$\(*)		COMPREPLY=($(compgen -c -P '$(' -S ')'  -- ${c#??}))	;;
    \`*\`)	   eval COMPREPLY=\(${c}\) ;;
    \`*)		COMPREPLY=($(compgen -c -P '\`' -S '\`' -- ${c#?}))	;;
    \$\{*\})	   eval COMPREPLY=\(${c}\) ;;
    \$\{*)		COMPREPLY=($(compgen -v -P '${' -S '}'  -- ${c#??}))	;;
    \$*)		COMPREPLY=($(compgen -v -P '$'          -- ${c#?}))	;;
    \~*/*)		COMPREPLY=($(compgen -f -X "$e"         -- ${c}))	;;
    \~*)		COMPREPLY=($(compgen -u ${s}	 	-- ${c}))	;;
    *@*)		COMPREPLY=($(compgen -A hostname -P '@' -S ':' -- ${c#*@})) ;;
    *[*?[]*)		COMPREPLY=()			# use bashdefault
			test $g -eq 0 && shopt -u extglob
			return 0						;;
    *[?*+\!@]\(*\)*)
	if test $g -eq 0 ; then
			COMPREPLY=($(compgen -f -X "$e" -- $c))
			test $g -eq 0 && shopt -u extglob
			return 0
	fi
			COMPREPLY=($(compgen -G "${c}"))			;;
    *)
	if test "$c" = ".." ; then
			COMPREPLY=($(compgen -d -X "$e" ${_nosp} -- $c))
	else
			COMPREPLY=($(compgen -f -X "$e" -- $c))
	fi
    esac

    if test -n "$t" ; then
	let o=0
	local -a reply=()
	_compreply_
	for s in ${COMPREPLY[@]}; do
	    e=$(eval echo $s)
	    if test -d "$e" ; then
		reply[$((o++))]="$s"
		continue
	    fi
	    case "$(file -b $e 2> /dev/null)" in
	    $t)	reply[$((o++))]="$s"
	    esac
	done
	COMPREPLY=(${reply[@]})
	test $g -eq 0 && shopt -u extglob
	return 0
    fi

    _compreply_

    test $g -eq 0 && shopt -u extglob
    return 0
}

_gdb_ ()
{
    local c=${COMP_WORDS[COMP_CWORD]}
    local e p
    local -i o
    local IFS

    if test $COMP_CWORD -eq 1 ; then
	case "$c" in
 	-*) COMPREPLY=($(compgen -W '-args -tty -s -e -se -c -x -d' -- "$c")) ;;
	*)  COMPREPLY=($(compgen -c -- "$c"))
	esac
	return 0
    fi

    p=${COMP_WORDS[COMP_CWORD-1]}
    IFS=$'\n'
    case "$p" in
    -args)	COMPREPLY=($(compgen -c -- "$c")) ;;
    -tty)	COMPREPLY=(/dev/tty* /dev/pts/*)
		COMPREPLY=($(compgen -W "${COMPREPLY[*]}" -- "$c")) ;;
    -s|e|-se)	COMPREPLY=($(compgen -f -- "$c")) ;;
    -c|-x)	COMPREPLY=($(compgen -f -- "$c")) ;;
    -d)		COMPREPLY=($(compgen -d ${_nosp} -- "$c")) ;;
    *)
		if test -z "$c"; then
		    COMPREPLY=($(command ps axho comm,pid |\
				 command sed -rn "\@^${p##*/}@{ s@.*[[:blank:]]+@@p; }"))
		else
		    COMPREPLY=()
		fi
		let o=${#COMPREPLY[*]}
		_compreply_
		for s in $(compgen -f -- "$c") ; do
		    e=$(eval echo $s)
		    if test -d "$e" ; then
			COMPREPLY[$((o++))]="$s"	
			continue
		    fi
		    case "$(file -b $e 2> /dev/null)" in
		    *)	COMPREPLY[$((o++))]="$s"
		    esac
		done
    esac 
    return 0
}

complete ${_def} -X '.[^./]*' -F _exp_ ${_file} \
				 	compress \
					bzip2 \
					bunzip2 \
					gzip \
					gunzip \
					uncompress \
					unzip \
					gs ghostview \
					gv kghostview \
					acroread xpdf kpdf \
					evince rpm zypper \
					dvips xdvi kdvi \
					tex latex pdflatex

complete ${_def} -F _exp_ ${_file} 	chown chgrp chmod chattr ln
complete ${_def} -F _exp_ ${_file} 	more cat less strip grep vi ed

complete ${_def} -A function -A alias -A command -A builtin \
					type
complete ${_def} -A function		function
complete ${_def} -A alias		alias unalias
complete ${_def} -A variable		unset local readonly
complete ${_def} -F _exp_ ${_nosp}	export
complete ${_def} -A variable -A export	unset
complete ${_def} -A shopt		shopt
complete ${_def} -A setopt		set
complete ${_def} -A helptopic		help
complete ${_def} -A user		talk su login sux
complete ${_def} -A builtin		builtin
complete ${_def} -A export		printenv
complete ${_def} -A command		command which nohup exec nice eval 
complete ${_def} -A command		ltrace strace
complete ${_def} -F _gdb_ ${_file}  	gdb
HOSTFILE=""
test -s $HOME/.hosts && HOSTFILE=$HOME/.hosts
complete ${_def} -A hostname		ping telnet slogin rlogin \
					traceroute nslookup
complete ${_def} -A hostname -A directory -A file \
					rsh ssh scp
complete ${_def} -A stopped -P '%'	bg
complete ${_def} -A job -P '%'		fg jobs disown

# Expanding shell function for manual pager
_man_ ()
{
    local c=${COMP_WORDS[COMP_CWORD]}
    local o=${COMP_WORDS[COMP_CWORD-1]}
    local os="- f k P S t l"
    local ol="whatis apropos pager sections troff local-file"
    local m s

    if test -n "$MANPATH" ; then
	m=${MANPATH//:/\/man,}
    else
	m="/usr/X11R6/man/man,/usr/openwin/man/man,/usr/share/man/man"
    fi

    case "$c" in
 	 -) COMPREPLY=($os)	;;
	--) COMPREPLY=($ol) 	;;
 	-?) COMPREPLY=($c)	;;
	\./*)
	    COMPREPLY=($(compgen -f -d -X '\./.*'  -- $c)) ;;
    [0-9n]|[0-9n]p)
	    COMPREPLY=($c)	;;
	 *)
	case "$o" in
	    -l|--local-file)
		COMPREPLY=($(compgen -f -d -X '.*' -- $c)) ;;
	[0-9n]|[0-9n]p)
		s=$(eval echo {${m}}$o/)
		if type -p sed &> /dev/null ; then
		    COMPREPLY=(\
			$(command ls -1UA $s 2>/dev/null|\
			  command sed -rn "/^$c/{s@\.[0-9n].*\.gz@@g;s@.*/:@@g;p;}")\
		    )
		else
		    s=($(ls -1fUA $s 2>/dev/null))
		    s=(${s[@]%%.[0-9n]*})
		    s=(${s[@]#*/:})
		    for m in ${s[@]} ; do
			case "$m" in
			    $c*) COMPREPLY=(${COMPREPLY[@]} $m)
			esac
		    done
		    unset m s
		    COMPREPLY=(${COMPREPLY[@]%%.[0-9n]*})
		    COMPREPLY=(${COMPREPLY[@]#*/:})
		fi					   ;;
	     *) COMPREPLY=($(compgen -c -- $c))		   ;;
	esac
    esac
}

complete ${_def} -F _man_ ${_file}		man

_rootpath_ ()
{
    local c=${COMP_WORDS[COMP_CWORD]}
    local os="-h -K -k -L -l -V -v -b -E -H -P -S -i -s"
    local ox="-r -p -t -u"
    case "$c" in
	-*) COMPREPLY=($(compgen -W "$os $ox" -- "$c")) ;;
	*)  if ((COMP_CWORD <= 1)) ; then
		COMPREPLY=($(PATH=/sbin:/usr/sbin:$PATH:/usr/local/sbin compgen -c -- "${c}"))
	    else
		COMPREPLY=()
	    fi
    esac
}

complete ${_def} -F _rootpath_			sudo

unset _def _dir _file _nosp

#
# End of /etc/profile.d/complete.bash
#
