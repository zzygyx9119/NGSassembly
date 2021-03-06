#!/bin/bash

. functions.inc

###########################################################
# Genome assembly pipeline using Marthlab Mosaik suite of #
# programs, SNP calling using FreeBayes                   #
# Automated and interactive bash script using multiple    #
# threads and large amount of RAM                         #
# Script originally by Marcin Kierczak                    #
# Marcin.Kierczak@hgen.slu.se, date: 18.05.2010           #
# Modified and expanded by: Andreas.E.Lundberg@gmail.com  #
# Date: 14.07.2011                                        #
###########################################################

# Genome assembly pipeline using Mosaik suite of programs and SNP calling with FreeBayes
# Automated and interactive bash script using multiple threads for speed
# Alignment is done in linear processing fashion using multiple cores.
#
# First set up working directories and pipeline variables
# This analysis pipeline requires a lot of disk space.
# Make sure paths are set correctly as script will replace existing results directory


####################### Text color variables ##############################
txtund=$(tput sgr 0 1)    # Underline
txtbld=$(tput bold)       # Bold
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtblu=$(tput setaf 4)    # Blue
txtpur=$(tput setaf 5)    # Purple
txtcyn=$(tput setaf 6)    # Cyan
txtwht=$(tput setaf 7)    # White
txtrst=$(tput sgr0)       # Text reset

################### Variables for analysis pipeline #########################
#------------------- Folder settings -----------------------
main_dir=`pwd`
project_name="gallus"								# Project name, preferably the organism genome name, e.g. galGal3

mosaik_dir=~andreas/NGSprograms						# Programs bin/ directory, all programs required in same directory
refseq_dir=~/galGal3/refseq							# Directory containing reference sequences
results_dir=$main_dir/$project_name".results"				# Directory to store the results
reads_dir=/usr/gallus/binary.reads						# Directory containing reads

lines="high low"

# gallus_high_frag_35bp_1.filtered.dat  gallus_high_mate_2x50bp.filtered.dat               gallus_low_frag_35bp_1.filtered.dat  gallus_low_mate_2x50bp.filtered.dat
# gallus_high_frag_35bp_2.filtered.dat  gallus_high_orphaned_mates_50bp.F3R3.filtered.dat  gallus_low_frag_35bp_2.filtered.dat  gallus_low_orphaned_mates_50bp.F3R3.filtered.dat


#------------------- Settings for Mosaik pipeline -----------------------
proc=16			#Number of processor cores available, -p=16
#memory=70375828		#Number of hashes to be stored in memory (default=6000000) 
#QV_filter=20		#Filtering of raw reads, phred scores, >20
hash_size=15		#Hash size, -hs=15
mhp=100			#Number of stored hash positions, -mhp=100

SE_mismatches=4		#Maximum allowed mismatches in read, -mm=4 for single-end, -mm=6 for mate-pairs
MP_mismatches=6
SE_act=20			#Alignment threshold, -act=20 for single-end, -act=25 for mate-pairs
MP_act=25
SE_bandwidth=13		#Bandwith for banded Smith-Waterman algorithm, -bw=13 for single-end; -bw=17 for mate-pairs
MP_bandwidth=17

mfl=3528			#Mean fragment length in bp for mate-pairs
radius=4000			#Search radius from mfl in bp
threads=2
#threads=`echo $lines | wc -w`

#------------------- Settings for SNP calling -----------------------
poly_prob=0.0001		#Polymorphism probability threshold
CAL=3				#SNP calling minimum number of reads
MAQ=15			#MAQ mapping alignment quality
BAQ=15			#BAQ base quality
ploidy=22			#For 11 diploid individuals in pool (e.g. high or low) this number is 22

######################## Script functions ################################
Pause() {
	read -p "Press any key to continue..." -n 1 -s
}

function Presentation {
# Presentation output
echo -e "$txtgrn###############################################################"
echo -e "# Bash script for running Mosaik Assembly pipeline            #"
echo -e "# and calling SNPs and short indels using FreeBayes           #"
echo -e "# whole genome assembly                                       #"
echo -e "# Author: Marcin.Kierczak@hgen.slu.se                         #"
echo -e "# Written: 18.05.2010                                         #"
echo -e "# ----------------------------------------------------------- #"
echo -e "# Modified and expanded                                       #"
echo -e "# Co-author: Andreas.E.Lundberg@gmail.com                     #"
echo -e "# GitHub repo: git://github.com/Papegoja/NGSassembly.git      #"
echo -e "# Date: 13.07.2011                                            #"
echo -e "############################################################### $txtrst \n"

echo -e $txtylw"Program assembles genome from concatenated chromosome fasta files, one file residing in reference sequence directory." 
echo -e "First set up working directories and pipeline variables. "
echo -e "Originally written for SOLiD reads taking two different read lengths into account, 35bp fragment and 2x50bp mate-pair runs. "
echo -e "Alignment is done in linear processing fashion using multiple cores. Other steps are run in parallel. "
echo -e "SNP calling is done in streaming fashion after merging of lines. Alignments are sorted and converted to BAM file format. "
echo -e "BAM files are processed and duplicate reads are removed using Picard MarkDuplicates. "
echo -e "Read-groups and sample names added to files using bamaddrg and streamed to FreeBayes for SNP calling. "
echo -e "This analysis pipeline requires a lot of disk space. $txtredMake sure paths are set correctly as script will replace existing results directory. "
echo -e "All programs need to reside in same directory !! $txtrst"
echo -e $txtylw"The reads files are processed from reads directory using list *.dat command $txtrst"
echo -e $txtred"The read length followed by bp (e.g. \"35bp\" or \"50bp\") must be contained in the binary read archive name. \n\n"
}

function DrawMenu {
echo -e $txtblu"###########################################################################################"
echo -e "#                                       Menu                                              #"
echo -e "########################################################################################### $txtrst \n"
echo -e $txtylw"Initialize analysis with \t I $txtrst"
echo -e $txtred"Quit program with \t\t Q $txtrst \n"

echo -e $txtgrn"########################### Folder paths ################################ $txtrst"
echo -e "1) Project name, preferably genome name: \t\t\t $project_name"
echo -e "2) Directory of programs: \t\t\t\t\t $mosaik_dir"
echo -e "3) Directory with genome reference sequence, .fa file: \t\t $refseq_dir"
echo -e "4) Reads directory: \t\t\t\t\t\t $reads_dir"
echo -e "5) Results directory: \t\t\t\t\t\t $results_dir \n"
echo -e "   Library names: \t\t\t\t\t\t $lines \n\n"
#echo -e "7) INDEL calling , default"


echo -e $txtgrn"################# Assembly-specific settings ############################ $txtrst"
echo -e "P) Processors used for alignment, default 16: \t\t\t\t $txtred$proc$txtrst \t processors"
echo -e "H) Hash size, single-end default 15: \t\t\t\t\t $txtred$hash_size$txtrst \t hash size"
echo -e "J) Maximum hash positions, default 100: \t\t\t\t $txtred$mhp$txtrst \t max hash positions"
echo -e "\nM) Single-end maximum mismatches allowed, 35bp default 4: \t\t $txtred$SE_mismatches$txtrst \t SE mismatches"
echo -e "N) Mate-pair/paired-end maximum mismatches allowed, 50bp default 6: \t $txtred$MP_mismatches$txtrst \t MP mismatches" 
echo -e "\nA) Single-end alignment candidate threshold, SE default 20: \t\t $txtred$SE_act$txtrst \t SE alignment candidate threshold"
echo -e "B) Mate-pair/paired-end alignment candidate threshold, MP default 25: \t $txtred$MP_act$txtrst \t MP alignment candidate threshold"
echo -e "\nC) Single-end Smith-Waterman bandwidth, SE default 13: \t\t\t $txtred$SE_bandwidth$txtrst \t SE SW bandwidth"
echo -e "D) Mate-pair/paired-end Smith-Waterman bandwidth, MP default 17: \t $txtred$MP_bandwidth$txtrst \t MP SW bandwidth \n\n"
#echo -e "F) Mean fragment length/insert size: \t\t\t\t\t $txtred$mfl$txtrst\t bp mean fragment length"
#echo -e "R) Search radius from mean fragment length: \t\t\t\t $txtred$radius$txtrst\t bp radius"
#echo -e "T) Parallel threads created in pipeline steps, default 14: \t\t $txtred$threads$txtrst \t threads"
#echo -e "   Sort, MarkDuplicates, Text, CallSNP \n\n"


echo -e $txtgrn"################# Settings for SNP calling ############################## $txtrst"
echo -e "S) SNP calling probability threshold, default 0.0001: \t\t\t $txtred$poly_prob$txtrst \t calling probabilty"
echo -e "R) Minimum number of reads per SNP call, default 3: \t\t\t $txtred$CAL$txtrst \t minimum reads"
echo -e "U) Minimum required mapping quality for alignment, default 15: \t\t $txtred$MAQ$txtrst \t mapping quality"
echo -e "V) Minimum required base quality for sequencing read, default 15: \t $txtred$BAQ$txtrst \t base quality"
echo -e "W) Ploidy for pooled samples, total number of alleles in each pool: \t $txtred$ploidy$txtrst \t mapping quality \n\n"

echo -e $txtblu"################# Enter choice ############################## $txtrst \n"
echo -ne $txtpur"Enter corresponding character to update setting.$txtcyn Start analysis with I$txtred, quit with Q: $txtrst"

UpdateSettings
}

function UpdateSettings() {
	read menu_choice
	while true
	do
		case "$menu_choice" in
		"1" ) 
			echo -ne $txtred"Enter new value: $txtrst"
			read
			project_name=$REPLY
			results_dir=$main_dir/$project_name".results"
		;;
		"2" ) 
			echo -ne $txtred"Enter new value: $txtrst"
			read
			mosaik_dir=$REPLY
		;;
		"3" ) 
			echo -ne $txtred"Enter new value: $txtrst"
			read
			refseq_dir=$REPLY
		;;
		"4" ) 
			echo -ne $txtred"Enter new value: $txtrst"
			read
			reads_dir=$REPLY
		;;
		"5" ) 
			echo -ne $txtred"Enter new value: $txtrst"
			read
			results_dir=$REPLY
		;;
		"6" ) 
			echo -ne $txtred"Enter new value: $txtrst"
			read
			lines=$REPLY
		;;
		"P" | "p" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			proc=$REPLY
		;;
		"H" | "h" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			hash_size=$REPLY
		;;
		"J" | "j" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			mhp=$REPLY
		;;
		"M" | "m" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			SE_mismatches=$REPLY
		;;
		"N" | "n" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			MP_mismatches=$REPLY
		;;
		"A" | "a" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			SE_act=$REPLY
		;;
		"B" | "b" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			MP_act=$REPLY
		;;
		"C" | "c" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			SE_bandwidth=$REPLY
		;;
		"D" | "d" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			MP_bandwidth=$REPLY
		;;
#		"F" | "f" )
#			echo -ne $txtred"Enter new value: $txtrst"
#			read
#			mfl=$REPLY
#		;;
#		"R" | "r" )
#			echo -ne $txtred"Enter new value: $txtrst"
#			read
#			radius=$REPLY
#		;;
		"T" | "t" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			threads=$REPLY
		;;
		"S" | "s" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			poly_prob=$REPLY
		;;
		"R" | "r" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			CAL=$REPLY
		;;
		"U" | "u" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			MAQ=$REPLY
		;;
		"V" | "v" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			BAQ=$REPLY
		;;
		"W" | "w" )
			echo -ne $txtred"Enter new value: $txtrst"
			read
			ploidy=$REPLY
		;;
		"Q" | "q" )
			echo
			exit 0
		;;
		"I" | "i" )
			break
		;;
		esac
		clear
		DrawMenu
	done
}


######################## Start script ################################

clear 
Presentation 
Pause
clear
DrawMenu

# Clean results dir, all sub-directories and log-files removed 
#rm -rf $results_dir #2>/dev/null
#rm *.log 2>/dev/null
#rm -rf /tmp/*.tmp 2>/dev/null

######################## Initialize pipeline #########################
echo -e "\n\n$txtpur INITIALIZE PIPELINE $txtrst"
startrun=$SECONDS

#cd $refseq_dir
#list=`ls $refseq_dir/*chr*.fa | awk -F"/" '{print $NF}'`			# gives basename, i.e. chrM.fa or v_chr13.fa
#list
#mkdir $project_name 2>/dev/null

mkdir $results_dir 2>/dev/null

# reads=`ls $reads_dir/*.dat`

file=`ls $refseq_dir/*.fa | awk -F "/" '{print $NF}'`				# this is refseq filename, used in functions
genomes=`ls $reads_dir | awk -F "/" '{print $NF}'` 				# filename of binary archive for sequencing run; NF='number of fields' aka. last field

echo $project_name
echo $results_dir
echo $reads_dir
echo $file
echo $genomes

############################ Assembly loop ############################
# Semi-sequential run

Build	&					# detachable process
BuildCS					# non-detachable process
JumpDB 					# dependent on BuildCS
sleep 8
for genome in $genomes; do
	start=$SECONDS
	echo -e "Processing $genome..." | tee -a $results_dir/pipeline.log
	mkdir $results_dir/$genome 2>/dev/null

	Align					# utilizes $proc processors
	
	end=$SECONDS
	exectime=$((end - start))
	echo -e "done in $exectime seconds.\n\n" | tee -a $results_dir/pipeline.log
done


#################### Alignment manipulation loop ######################
# STM, Sort -> Text -> MarkDuplicates loop

	for genome in $genomes; do
		start=$SECONDS
		echo -e "Sorting, converting and marking duplicates for $genome..." | tee -a $results_dir/pipeline.log		
		## All alignment manipulation loops run in parallel over $threads

		Sort
		Text
		MarkDuplicates
		# BAMIndex &
		
		end=$SECONDS
		exectime=$((end - start))
		echo -e "done in $exectime seconds.\n\n" | tee -a $results_dir/pipeline.log
	done


######################### GATK local realignment and BAQ adjustment ############################
#NUM=0
#QUEUE=""
#
#	for genome in $genomes; do
#		start=$SECONDS		
#		echo -e "BAM leftalign and BAQ adjustment in $genome..." | tee -a $results_dir/pipeline.log
#		GATKBAQ &				# Start and detach process		
#		PID=$!					# Get PID of process just started
#		queue $PID					# 
#		# Spawn process
#		while [ $NUM -ge 4 ]; do 		# If $NUM is greater or equal to $threads check and regenerate queue
#			checkqueue
#			sleep 10
#		done
#		wait
#		end=$SECONDS
#		exectime=$((end - start))
#		echo -e "done in $exectime seconds.\n\n" | tee -a $results_dir/pipeline.log
#	done
#wait

############################# SNP calling loop ################################
# Multi-threaded SNP calling, high- and low-line calling done separately

# left over remnants from chromosome by chromosome parallel execution 
#NUM=0
#QUEUE=""
#for file in $list; do

#	chromosome=${file%\.*}
#	echo -e "Calling SNPs in $genome..." | tee -a $results_dir/pipeline.log

#	lines=`ls $reads_dir/*.dat | awk -F "/" '{print $NF}' | awk -F "_" '{print $2}'`
	
#	for line in $lines; do
		start=$SECONDS		
		echo -e "Calling SNPs for \"$lines\" in $project_name..." | tee -a $results_dir/pipeline.log

#		mkdir $results_dir/SNPcalling
		## SNP calls in $threads number of threads

		CallSNP					# Start and detach process		

#		PID=$!					# Get PID of process just started
#		queue $PID					# 
#		# Spawn process
#		while [ $NUM -ge $threads ]; do 	# If $NUM is greater or equal to $threads check and regenerate queue
#			checkqueue
#			sleep 10
#		done

#		wait
		end=$SECONDS
		exectime=$((end - start))
		echo -e "SNP calling done in $exectime seconds.\n\n" | tee -a $results_dir/pipeline.log
#	done
#done


endrun=$SECONDS
totaltime=$((endrun - startrun))
echo -e $txtylw "\nComplete assembly and SNP calling done in $totaltime seconds. $txtgrn \nRun completed. $txtrst \n" | tee -a $results_dir/pipeline.log




