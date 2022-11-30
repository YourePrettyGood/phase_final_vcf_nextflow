#!/usr/bin/env nextflow
/* One-step pipeline to deduplicate alignments in a BAM, subset by          *
 * chromosome                                                               */

//Default paths, globs, and regexes:
//Glob for the per-individual BAMs:
params.bam_glob = "${projectDir}/BAMs/*_MD_IR_recal.bam"
//Regex for parsing the sample ID out of the BAM filename:
params.bam_regex = ~/^(.+)_MD_IR_recal$/

//Set up the channels of BAMs and their indices:
num_samples = file(params.bam_glob, checkIfExists: true).size()
println "Found ${num_samples} BAMs in the input directory"
Channel
   .fromPath(params.bam_glob, checkIfExists: true)
   .ifEmpty { error "Unable to find BAMs matching glob: ${params.bam_glob}" }
   .map { bam -> return [(bam.getSimpleName() =~ params.bam_regex)[0][1], bam] }
   .tap { bams }
   .subscribe { println "Added ${it[0]} (${it[1]}) to bams channel" }
Channel
   .fromPath(params.bam_glob+".bai", checkIfExists: true)
   .ifEmpty { error "Unable to find BAM indices matching glob: ${params.bam_glob}.bai" }
   .map { bai -> return [(bai.getSimpleName() =~ params.bam_regex)[0][1], bai] }
   .tap { bais }
   .subscribe { println "Added ${it[0]} (${it[1]}) to bais channel" }

//Set up the channel of chromosomes:
chromosomes = Channel.value(params.chroms.tokenize(","))

//Default parameter values:
//Include -n if you need to eliminate pesky duplicated
// alignments that have differing CIGAR strings,
// though be aware that this also throws out some
// non-duplicate supplementary alignments.
//You could -a or -b to set the initial buffer sizes 
params.dedup_extraopts = "-n"

//Defaults for cpus, memory, and time for each process:
//Subset by chrom and dedup
params.dedup_cpus = 1
params.dedup_mem = 1
params.dedup_timeout = '2h'

process dedup {
   tag "${id} chr${chr}"

   cpus params.dedup_cpus
   memory { params.dedup_mem.plus(task.attempt.minus(1).multiply(16))+' GB' }
   time { task.attempt >= 2 ? '48h' : params.dedup_timeout }
   errorStrategy { task.exitStatus in 134..140 ? 'retry' : 'terminate' }
   maxRetries 1

   publishDir path: "${params.output_dir}/logs", mode: 'copy', pattern: '*.std{err,out}'
   publishDir path: "${params.output_dir}/filtered_BAMs", mode: 'copy', pattern: '*.ba{m,m.bai}'

   input:
   tuple val(id), path(bam), path(bai), val(chr) from bams.join(bais, by: 0, failOnDuplicate: true, failOnMismatch: true).combine(chromosomes)

   output:
   tuple path("samtools_view_${id}_chr${chr}.stderr"), path("samtools_view_${id}_chr${chr}.stdout"), path("dedup_merged_bams_${id}_chr${chr}.stderr"), path("dedup_merged_bams_${id}_chr${chr}.stdout") into dedup_logs
   tuple path("${id}_chr${chr}_MD_IR_recal_filtered.bam"), path("${id}_chr${chr}_MD_IR_recal_filtered.bam.bai") into deduped_bams

   shell:
   '''
   module load !{params.mod_samtools}
   module load !{params.mod_dedup}
   #Subset out chr!{chr} from the whole-genome BAM of !{id}:
   samtools view -b -o !{id}_chr!{chr}.bam !{bam} !{chr} 2> samtools_view_!{id}_chr!{chr}.stderr > samtools_view_!{id}_chr!{chr}.stdout
   samtools index !{id}_chr!{chr}.bam
   #Remove duplicated alignments from the subset BAM:
   dedup_merged_bams -i !{id}_chr!{chr}.bam -o !{id}_chr!{chr}_MD_IR_recal_filtered.bam -t !{task.cpus} -d !{params.dedup_extraopts} 2> dedup_merged_bams_!{id}_chr!{chr}.stderr > dedup_merged_bams_!{id}_chr!{chr}.stdout
   samtools index !{id}_chr!{chr}_MD_IR_recal_filtered.bam
   #Remove the subset but unfiltered BAM to save disk space:
   rm !{id}_chr!{chr}.ba{m,m.bai}
   '''
}
