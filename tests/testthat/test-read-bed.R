context(".bed")

bed_df <- readr::read_csv("bed_results.bed", col_types = "cdi")

test_that("read_bed split size, correct region split", {
  bed_test <- read_bed("basic.bed")

  expect_that(nrow(bed_test), equals(21))
  expect_that(bed_test$chrom, equals(bed_df$chrom))
  expect_true(is.numeric(bed_test$start))
  expect_true(is.numeric(bed_test$end))
  expect_that(bed_test, equals(bed_df))
})

test_that("read_bed including header", {
  bed_test <- read_bed("with_header.bed", header = TRUE)

  expect_that(nrow(bed_test), equals(21))
  expect_that(bed_test, equals(bed_df))
})

test_that("read_bed ucsc coordinate shift", {
  bed_test <- read_bed("with_header.bed", header = TRUE, ucsc_coord = TRUE)

  expect_that(nrow(bed_test), equals(21))
  expect_that(bed_test$start[1], equals(12764911))
  expect_that(bed_test$start[17], equals(133006534))
  expect_that(bed_test$end[18], equals(14402))
  expect_that(bed_test$end[13], equals(179884855))

})

test_that("read_bed custom regions_size", {
  bed_test <- read_bed("with_header.bed", header = TRUE, ucsc_coord = TRUE,
    bed_region_size = 2^10)
  expect_that(nrow(bed_test), equals(236))
  expect_that(ncol(bed_test), equals(3))
})

test_that("checkRegionSize test if correct region supplied", {
  region_size <- checkRegionSize(2000, c(12, 20, 1999, 2000, 5000))

  expect_that(region_size, equals(1024))
})