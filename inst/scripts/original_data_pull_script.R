# demographics
demo <- pull_nhanes("demo") # 113249

# acculturation
acq <- pull_nhanes("acq") # 89381

# allergies
agq <- pull_nhanes("agq") # 9822

# alcohol
alq <- pull_nhanes("alq") # 59896

# audiometry
auq <- pull_nhanes("auq") # 98785

# blood pressure & cholesterol questionnaire
bpq <- pull_nhanes("bpq") # 72093

# cardiovascular health
cdq <- pull_nhanes("cdq") # 36252

# cormorbidity functioning
cfq <- pull_nhanes("cfq") # 7178

# consumer behavior
cbq <- pull_nhanes("cbq") # 59842

# creatinine kinase
ckq <- pull_nhanes("ckq") # 13528

# diabetes
diq <- pull_nhanes("diq") # 108555

# dietary interview, individual food first day
dr1iff <- pull_nhanes("dr1iff") # 1166975

# dietary interview, second day
dr2iff <- pull_nhanes("dr2iff") # 1010395

# total nutrient intake, first day
dr1tot <- pull_nhanes("dr1tot") # 85867

# total nutrient intake, second day
dr2tot <- pull_nhanes("dr2tot") # 85867

# food codes -- REVISIT THIS LATER: NO SEQN VARIABLE
# drxfcd <- pull_nhanes('drxfcd')

# modification codes -- SAME AS ABOVE
# drxmcd <- pull_nhanes('drxmcd')

# substance use
duq <- pull_nhanes("duq") # 41709

# dermatology
deq <- pull_nhanes("deq") # 41880

# diet, behavior, & nutrition
dbq <- pull_nhanes("dbq") # 113249

# disability
dlq <- pull_nhanes("dlq") # 28242

# mental health -- depression screener
dpq <- pull_nhanes("dpq") # 46833

# early childhood
ecq <- pull_nhanes("ecq") # 38063

# food security
fsq <- pull_nhanes("fsq") # 113249

# health insurance
hiq <- pull_nhanes("hiq") # 113249

# hepatitis
heq <- pull_nhanes("heq") # 35513

# current health status
hsq <- pull_nhanes("hsq") # 99855

# hospital utilization & access to care
huq <- pull_nhanes("huq") # 113249

# immunization
imq <- pull_nhanes("imq") # 112881

# income
inq <- pull_nhanes("inq") # 71775

# kidney conditions & urology
# 1999
kiq <- pull_nhanes("kiq") # 4880
# 2001+
kiq_u <- pull_nhanes("kiq_u") # 58010

# prostate conditions
kiq_p <- pull_nhanes("kiq_p") # 12652

# cancer questions
mcq <- pull_nhanes("mcq") # 108555

# occupation
ocq <- pull_nhanes("ocq") # 73344

# oral health
ohq <- pull_nhanes("ohq") # 94979

# osteoporosis
osq <- pull_nhanes("osq") # 39348

# pesticide use
puqmec <- pull_nhanes("puqmec") # 64445

# physical activity -- individual activities
paqiaf <- pull_nhanes("paqiaf") # 49784

# phyiscal functioning
pfq <- pull_nhanes("pfq") # 93104

# prescription medication -- MULTIPLE ROWS PER PARTICIPANT
rxq_rx <- pull_nhanes("rxq_rx") # 202009

# prescription medication -- drug information
# rxq_drug <- pull_nhanes('rxq_drug')

# physical activity
paq <- pull_nhanes("paq") # 98969

# PSA follow-up
psq <- pull_nhanes("psq") # 173

# respiratory health
rdq <- pull_nhanes("rdq") # 68569

# reproductive health
rhq <- pull_nhanes("rhq") # 39362

# sleep disorders
slq <- pull_nhanes("slq") # 53202

# smoking
smq <- pull_nhanes("smq") # 73889

# smoking -- household
smqfam <- pull_nhanes("smqfam") # 113249

# smoking recent tobacco use
smqrtu <- pull_nhanes("smqrtu") # 55138

# social support
ssq <- pull_nhanes("ssq") # 14086

# sexual behavior
sxq <- pull_nhanes("sxq") # 37137

# vision
viq <- pull_nhanes("viq") # 24464

# weight history
whq <- pull_nhanes("whq") # 72093

# weight history -- youth
whqmec <- pull_nhanes("whqmec") # 10566


# albumin & creatinine
alb_cr <- pull_nhanes("alb_cr") # 65958

# audiometry
aux <- pull_nhanes("aux") # 22760

# audiometry -- accoustic reflex
auxar <- pull_nhanes("auxar") # 101651

# more glucose, etc.
biopro <- pull_nhanes("biopro") # 55138

# body measures
bmx <- pull_nhanes("bmx") # 105626

# blood pressure
bpx <- pull_nhanes("bpx") # 96766

# blood counts
cbc <- pull_nhanes("cbc") # 73218

# --------------------------------------------------------------------------------------
# NOTE: bodyscan has repeated meaures until 2005+. Do not use the full bodyscan in the
# analysis, but use the body dataset instead!
# More info here: https://wwwn.cdc.gov/nchs/data/nhanes/public/2005/datafiles/dxx_d.htm
# bodyscan
dxx <- pull_nhanes("dxx") # 57084

# Example if you\'d like to randomly samply one observation.
# This will only affect 2005 since that is the only cycle with
# repeated or imputed measures. Every other cycle is unaffected.
# CHOOSE WISELY!
#
# set.seed(305)
# dxx_red <- dxx |>
#   group_by(seqn) |>
#   slice_sample(n = 1)  # 29512
# --------------------------------------------------------------------------------------

# diabetes 2
ghb <- pull_nhanes("ghb") # 55138

# glucose
glu <- pull_nhanes("glu") # 27039

# cholesterol
hdl <- pull_nhanes("hdl") # 64445

# hiv
hiv <- pull_nhanes("hiv") # 26137

# cholesterol 2
tchol <- pull_nhanes("tchol") # 64445

# tryglyceride
trigly <- pull_nhanes("trigly") # 27039

# DEXA bodyscan -- android/gynoid measurements (non-repeated measures)
dxxag <- pull_nhanes("dxxag") # 37168

# glycohemoglobin (early naming, 2001-2004)
l10 <- pull_nhanes("l10") # 14435

# plasma fasting glucose, serum c-peptide & insulin (early naming, 2001-2004)
l10am <- pull_nhanes("l10am") # 7022

# glycohemoglobin (1999 naming)
lab10 <- pull_nhanes("lab10") # 6758

# plasma fasting glucose, serum c-peptide & insulin (1999 naming)
lab10am <- pull_nhanes("lab10am") # 3267
