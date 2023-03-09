#!/bin/bash 
#
#Trabalho 01 - SO - Taxas de Leitura/Escrita de processos em bash
#
# Cristiano Nicolau, 108536
# Tiago Cruz, 108615
#



#opcoes, caso os argumentos introduzidos sejam invalidos
function opcao(){
    echo "OPÇÃO INVÁLIDA!"
    echo ""
    echo "'-c': Seleção de processos a utilizar através de uma expressão regular" 
    echo "'-s': Seleção de processos a visualizar num periodo temporal (data mínima)"  
    echo "'-e': Seleção de processos a visualizar num periodo temporal (data máxima)"   
    echo "'-u': Seleção de processos a visualizar através do nome do utilizador" 
    echo "'-m': Seleção de processos a visualizar através da gama de pids (minimo)" 
    echo "'-M': Seleção de processos a visualizar através da gama de pids (maximo)" 
    echo "'-p': Número de processos a visualizar"  
    echo "'-r': Ordenação reversa"   
    echo "'-w': Ordenação da tabela por WRITER(decrescente)"   
    echo "O último argumento passado tem de ser um número (ultimos 's' segundos)" 
}


declare -A output=()   # Array guarda as informação de output, atraves do PID
declare -A Opt=()   # Array que guarda as  informações das opções 
declare -A RateR=()
declare -A WriteR=()

#dados
function processos() {
	
	for entry in /proc/[[:digit:]]*; do
           if [[ -r $entry/status && -r $entry/io ]]; then
            	pid=$(cat $entry/status | grep -w Pid | tr -dc '0-9') #PID
            	rcharinicial=$(cat $entry/io | grep rchar | tr -dc '0-9')   # rchar inicial
            	wcharinicial=$(cat $entry/io | grep wchar | tr -dc '0-9')   # wchar inicial

            	if [[ $rcharinicial == 0 && $wchar == 0 ]]; then
                   continue
            	else
                   RateR[$pid]=$(printf "%12d\n" "$rcharinicial")
                   WriteR[$pid]=$(printf "%12d\n" "$wcharinicial")
           	fi
           fi

    done
    
    sleep $1 # 'dorme' o input

    for entry in /proc/[[:digit:]]*; do

        if [[ -r $entry/status && -r $entry/io ]]; then

            pid=$(cat $entry/status | grep -w Pid | tr -dc '0-9') #PID
            user=$(ps -o user= -p $pid)                           #PID user
            comm=$(cat $entry/comm | tr " " "_") #comm
	    
	        #nome de utilizador
            if [[ -v Opt[u] && ! ${Opt['u']} == $user ]]; then
                continue
            fi

            #expressão regular
            if [[ -v Opt[c] && ! $comm =~ ${Opt['c']} ]]; then
                continue
            fi

  	        #PID
          #  if [[ -v Opt[m] && ! ${Opt['m']} == $pid ]]; then
           #     continue
            #fi

            if [[ -v Opt[m] ]]; then
                if [[ "$pid" -lt "${Opt['m']}" ]]; then
                    continue
                fi
            fi
            if [[ -v Opt[M] ]]; then
                if [[ "$pid" -gt "${Opt['M']}" ]]; then
                    continue
                fi
            fi

            LANG=en_us_8859_1
            Date=$(ps -o lstart= -p $pid) # data de início do processo atraves do PID
            Date=$(date +"%b %d %H:%M" -d "$Date")
            date=$(date -d "$Date" +"%b %d %H:%M"+%s | awk -F '[+]' '{print $2}') # data do processo (s)

            if [[ -v Opt[s] ]]; then                                                         #opção -s
                min=$(date -d "${Opt['s']}" +"%b %d %H:%M"+%s | awk -F '[+]' '{print $2}') # data mínima

                if [[ "$date" -lt "$min" ]]; then
                    continue
                fi
            fi

            if [[ -v Opt[e] ]]; then                                                       #opção -e
                max=$(date -d "${Opt['e']}" +"%b %d %H:%M"+%s | awk -F '[+]' '{print $2}') # data máxima

                if [[ "$date" -gt "$max" ]]; then
                    continue
                fi
            fi

            rcharfinal=$(cat $entry/io | grep rchar  | tr -dc '0-9') # rchar apos s segundos
            wcharfinal=$(cat $entry/io | grep wchar | tr -dc '0-9') # wchar apos s segundos
            subr=$rcharfinal-${RateR[$pid]}
            subw=$wcharfinal-${WriteR[$pid]}
            rateR=$(echo "scale=2; $subr/$1" | bc -l) # calculo do rateR
            rateW=$(echo "scale=2; $subw/$1" | bc -l) # calculo do rateW

            output[$pid]=$(printf "%-18s %-18s %15s %15s %15s %15s %15s %20s\n" "$comm" "$user" "$pid" "${RateR[$pid]}" "${WriteR[$pid]}" "$rateR" "$rateW" "$Date")
        fi

        
    done

    printf "%-18s %-18s %15s %15s %15s %15s %15s %20s\n" "COMM" "USER" "PID" "READB" "WRITEB" "RATER" "RATEW" "DATE"
    
    if ! [[ -v Opt[r] ]]; then
        ord="-n"
    else
        ord="-rn"
    fi

    
    #-p sem valor entao da print de todos
    if ! [[ -v Opt[p] ]]; then
        p=${#output[@]}
    #-p com valor nr de processos que da print
    else
        p=${Opt['p']}
    fi



    if [[ -v Opt[w] ]]; then
        #Ordenação da tabela pelo WriteValues
        printf '%s \n' "${output[@]}" | sort $ord -k7 | head -n $p

    else
        #Ordenação default da tabela, ord alfabética dos processos
	
        printf '%s \n' "${output[@]}" | sort $ord -k1 | head -n $p

    fi
    
   
}


while getopts "c:u:rs:e:m:M:wp:" option; do
    
    op='^[0-9]+([.][0-9]+)?$'    #ao utilizar cada possivel de selecao, é necessario para validar a strg 
    
    if [[ -z "$OPTARG" ]]; then               #Adiciona ao Opt as opcoes de entrada ao correr o scrip
        Opt[$option]=""                       #caso existam adiciona
    else                                      #caso não, adiciona "vazio"
        Opt[$option]=${OPTARG}
    fi
    
    case $option in
    c) 
        str=${Opt['c']}  #Seleção de processos por uma expressão regular
        if [[ $str == '' || ${str:0:1} == "-" || $str =~ $op ]]; then
            echo "Foi introduzido argumento inválido."
            echo "O argumento de '-c' não foi preenchido ou chamou sem '-' atrás da opção passada." >&2
            opcao
            exit 1
        fi
        ;;
    s)  
        str=${Opt['s']} #Seleção de processos data mínima
        regData='^((Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)) +[0-9]{1,2} +[0-9]{1,2}:[0-9]{1,2}'
        if [[ $str == '' || ${str:0:1} == "-" || $str =~ $op || ! "$str" =~ $regData ]]; then
            echo "Foi introduzido argumento inválido."
            echo "O argumento de '-s' não foi preenchido ou chamou sem '-' atrás da opção passada." >&2
            opcao
            exit 1
        fi
        ;;
    e)  
        str=${Opt['e']} #Seleção de processos data maxima
        regData='^((Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)) +[0-9]{1,2} +[0-9]{1,2}:[0-9]{1,2}'
        if [[ $str == '' || ${str:0:1} == "-" || $str =~ $op || ! "$str" =~ $regData ]]; then
            echo "Foi introduzido argumento inválido."
            echo "O argumento de '-e' não foi preenchido ou chamou sem '-' atrás da opção passada." >&2
            opcao
            exit 1
        fi
        ;;
    u)   
         str=${Opt['u']} #Seleção de processos nome do utilizador
	 if [[ $str == '' || ${str:0:1} == "-" || $str =~ $op ]]; then
           echo "Foi introduzido argumento inválido."
           echo "O argumento de '-u' não foi preenchido ou chamou sem '-' atrás da opção passada." >&2
           opcao
           exit 1
        fi
        ;;
    m)  
         #Seleção de processos gama de pids minimo
	 if ! [[ ${Opt['m']} =~ $op ]]; then
           echo "Foi introduzido argumento inválido."
           echo "O argumento de '-m' não foi preenchido ou chamou sem '-' atrás da opção passada." >&2
           opcao
           exit 1
        fi
        ;;
    M)  
         #Seleção de processos gama de pids maximo
	 if ! [[ ${Opt['M']} =~ $op ]]; then
           echo "Foi introduzido argumento inválido."
           echo "O argumento de '-M' não foi preenchido ou chamou sem '-' atrás da opção passada." >&2
           opcao
           exit 1
        fi
        ;;
    p)  
        if ! [[ ${Opt['p']} =~ $op ]]; then #Processos a visualizar
           echo "Foi introduzido argumento inválido."
           echo "O argumento de '-p' não foi preenchido ou chamou sem '-' atrás da opção passada." >&2
           opcao
            exit 1
        fi
        ;;
        
    r) #Ordenação reversa

        ;;
    w) #Ordenação WRITER

        ;;

    *)  echo "Foi introduzido argumento inválido."
        opcao #Argumentos inválidos
        exit 1
        ;;
    esac

done

if [[ $# == 0 ]]; then
    echo "Tem de passar no mínimo um argumento (nr segundos)."
    opcao
    exit 1
fi

# Verifica se o último argumento é um nr

if ! [[ ${@: -1} =~ $re ]]; then
    echo "Último argumento tem de ser um número."
    opcao
    exit 1
fi


processos ${@: -1} #input dos segundos
