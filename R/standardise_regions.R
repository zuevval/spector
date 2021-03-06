#' Read bed bed_file with bed_regions to run spector
#'
#' @param bed_file Path to the bed file
#' @param header logical. Set `TRUE` if the bed file contains a header.
#' @param ucsc_coord logical. Set `TRUE` if coordinates start with 0 like
#'        ucsc.
#' @param bed_region_size integer. Region size to normalise bed file.
#'
#' @return A `data.frame` used in the following calculations
#'
#' @importFrom dplyr select mutate
#' @importFrom readr read_tsv
#' @importFrom tibble as_data_frame
#' @importFrom magrittr %>%
#' @importFrom stringr str_c
#' @family data import functions
#'
#' @export
#'
read_bed <- function(bed_file, header = FALSE, ucsc_coord = FALSE,
                     bed_region_size = NULL) {

# column names and first line
# ----------------------------------------------------------------

  c_name <- c("chrom", "start", "end", "name", "score", "shade", "strand",
   "thickStart", "thickEnd", "itemRgb", "blockCount", "blockSizes",
   "blockStarts")

  if (header) {
    tmp_row1 <- read.table(bed_file , nrows = 1, skip = 1)
    skip_v <- 1
  } else {
    tmp_row1 <- read.table(bed_file , nrows = 1)
    skip_v <- 0
  }

# Reading bed files
# ----------------------------------------------------------------
  bed_region <-
    read_tsv(bed_file, skip = skip_v, col_names = c_name[1:3],
             col_types = c("cii", str_c(rep("_", length(tmp_row1) - 3),
                                        collapse = "")))

# Shift the data if ucsc convention
# ----------------------------------------------------------------

  if (ucsc_coord) {
    bed_region <- bed_region %>%
      mutate(start = start + 1)
    }

#
# Split regions
# --------------------------------------------------------------------------

  bed_region <-
    bed_region %>%
    mutate(reg_length = end - start) %>%
    bedRegionSplit(bed_region_size)

  return(bed_region)
}


# ==========================================================================
# Determine number of bed_regions to be split into and uncovered area
# ==========================================================================

#' @importFrom dplyr select mutate filter
#' @importFrom tibble as_data_frame
#' @importFrom magrittr %>%
#' @importFrom stringr str_c
#' @importFrom tidyr separate_rows separate
#'
bedRegionSplit <- function(bed_region, bed_region_size) {

  min_region <- checkRegionSize(bed_region_size, bed_region)
  bed_region <-
  bed_region %>%
    filter(reg_length >= min_region)

  if (length(unique(bed_region$reg_length)) > 1) {
    bed_region %>%
      mutate(
        n_reg = reg_length %/% min_region,
        uncov = reg_length %% min_region,
        new_reg = expandBedRegion(min_region, start, end, n_reg, uncov),
        orig_reg = str_c(chrom, ":", start, "-", end)
        ) %>%
      select(-start, -end, -reg_length) %>%
      separate_rows(new_reg, sep = ",") %>%
      separate(new_reg, into = c("start", "end"), convert = TRUE) %>%
      mutate(start = as.integer(start + 1)) %>%
      select(chrom, start, end)
    } else {
      bed_region %>%
        mutate(start = as.integer(start + 1)) %>%
        select(chrom, start, end)
    }
}

#' @importFrom dplyr summarise mutate
#'
checkRegionSize <- function(bed_region_size, file_region) {

  max_file <- file_region %>%
                summarise(tmp = max(reg_length)) %>%
                with(tmp)

  if (is.null(bed_region_size)) {
    message("No region size specified:
      Using largest power of 2 that fits into min(region) in the bed file")
    bed_region_size <- file_region %>%
                          summarise(tmp = 2^(floor(log2(min(reg_length))))) %>%
                          with(tmp)
  } else if (bed_region_size < 2^10) {
    stop("Region size below 2^10 is not supported,",
         " the LAS values are not meaningful.", call. = FALSE)
  } else {
    bed_region_size <- 2^(floor(log2(min(bed_region_size))))
    message(paste0("Regions standardised to length ", bed_region_size))
    n_drop <- file_region %>%
      mutate(filt = reg_length < bed_region_size) %>%
      summarise(n_drop = sum(filt)) %>%
      with(n_drop)
      message(paste0(n_drop,
                     " region(s) discarded because the length is smaller than ",
                     bed_region_size))
  }

  if (max_file < bed_region_size) {
    stop(paste0("min region size invalid
      Choose a number smaller than: ", max_file), call. = FALSE)
  } else {
    return(bed_region_size)
  }

}

# ==========================================================================
#
# ==========================================================================

#' @importFrom dplyr select mutate
#' @importFrom tibble as_data_frame
#' @importFrom magrittr %>%
#' @importFrom stringr str_c
#'
expandBedRegion <- function(bed_region_size, start, end, n_reg, uncov) {
sapply(seq_along(n_reg), function(i_v) {
  gap_bp <- round(uncov[i_v] / (n_reg[i_v] + 1))
  tmp_st <- c(rep(NA, n_reg[i_v]))
  tmp_ed <- c(start[i_v], rep(NA, n_reg[i_v]))
  res_v <- rep(NA, n_reg[i_v])

  for (i_n in 1:n_reg[i_v]) {
    tmp_st[i_n] <- tmp_ed[i_n] + gap_bp
    tmp_ed[i_n + 1] <- tmp_st[i_n] + bed_region_size
    res_v[i_n] <- str_c(as.integer(tmp_st[i_n]), "-",
                        as.integer(tmp_ed[i_n + 1]))
  }

  res_v %>% str_c(collapse = ",")
})

}


#' @importFrom stringr str_detect
#' @importFrom dplyr group_by filter mutate
#'
getRegions <- function(regions = "giab", f_bed = NULL, region_size = NULL,
                       header = FALSE, genome = "hg19", reg_overlap = 0) {
  checkGenome(genome)

  if (regions == "giab" & is.null(f_bed)) {

    region_df <-
      giab_10k %>%
        filter(genome == genome) %>%
        group_by() %>%
        mutate(reg_length = end - start) %>%
        bedRegionSplit(region_size)

  } else if (regions == "custom" & is.null(f_bed)) {

    stop("Selected custom region, but no bed file provided", call. = FALSE)

  } else if (!is.null(f_bed)) {

    region_df <- read_bed(bed_file = f_bed, header = header,
                          bed_region_size = region_size)
  } else if (regions %in% c("full.genome", "genome", "full")) {

    region_df <- full_genome_regions(genome_version = genome,
                                     region_size = region_size,
                                     reg_overlap = reg_overlap)
  }
  return(region_df)
}
