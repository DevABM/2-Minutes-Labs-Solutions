#!/bin/bash
# Define color variables

BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`
#----------------------------------------------------start--------------------------------------------------#

echo "${BG_MAGENTA}${BOLD}Starting Execution${RESET}"

export PROJECT_ID=$(gcloud config get-value project)

export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

export REGION=$(echo "$ZONE" | cut -d '-' -f 1-2)

gcloud dataplex lakes create sales-lake \
  --location=$REGION \
  --display-name="Sales Lake" \
  --description="Lake for sales data"

gcloud dataplex zones create raw-customer-zone \
  --lake=sales-lake \
  --location=$REGION \
  --resource-location-type=SINGLE_REGION \
  --display-name="Raw Customer Zone" \
  --type=RAW

gcloud dataplex zones create curated-customer-zone \
  --lake=sales-lake \
  --location=$REGION \
  --resource-location-type=SINGLE_REGION \
  --display-name="Curated Customer Zone" \
  --type=CURATED

gcloud dataplex assets create customer-engagements \
  --lake=sales-lake \
  --zone=raw-customer-zone \
  --location=$REGION \
  --display-name="Customer Engagements" \
  --resource-type=STORAGE_BUCKET \
  --resource-name=projects/$DEVSHELL_PROJECT_ID/buckets/$DEVSHELL_PROJECT_ID-customer-online-sessions

gcloud dataplex assets create customer-orders \
  --lake=sales-lake \
  --zone=curated-customer-zone \
  --location=$REGION \
  --display-name="Customer Orders" \
  --resource-type=BIGQUERY_DATASET \
  --resource-name=projects/$DEVSHELL_PROJECT_ID/datasets/customer_orders

gcloud data-catalog tag-templates create protected_customer_data_template \
    --location=$REGION \
    --display-name="Protected Customer Data Template" \
    --field=id=raw_data_flag,display-name="Raw Data Flag",type='enum(Yes|No)',required=TRUE \
    --field=id=protected_contact_information_flag,display-name="Protected Contact Information Flag",type='enum(Yes|No)',required=TRUE

gcloud dataplex assets add-iam-policy-binding customer-engagements --location=$REGION --lake=sales-lake --zone=raw-customer-zone --role=roles/dataplex.dataWriter --member=user:$USER_2

cat > dq-customer-orders.yaml <<EOF_CP
metadata_registry_defaults:
dataplex:
 projects: $DEVSHELL_PROJECT_ID
 locations: $REGION
 lakes: sales-lake
 zones: curated-customer-zone
row_filters:
NONE:
 filter_sql_expr: |-
   True
INTERNATIONAL_ITEMS:
 filter_sql_expr: |-
   REGEXP_CONTAINS(item_id, 'INTNL')
rule_dimensions:
- consistency
- correctness
- duplication
- completeness
- conformance
- integrity
- timeliness
- accuracy
rules:
NOT_NULL:
 rule_type: NOT_NULL
 dimension: completeness
rule_bindings:
VALID_CUSTOMER:
 entity_uri: bigquery://projects/$DEVSHELL_PROJECT_ID/datasets/customer_orders/tables/ordered_items
 column_id: user_id
 row_filter_id: NONE
 rule_ids:
   - NOT_NULL
VALID_ORDER:
 entity_uri: bigquery://projects/$DEVSHELL_PROJECT_ID/datasets/customer_orders/tables/ordered_items
 column_id: order_id
 row_filter_id: NONE
 rule_ids:
   - NOT_NULL
EOF_CP

gsutil cp dq-customer-orders.yaml gs://$DEVSHELL_PROJECT_ID-dq-config

echo "${CYAN}${BOLD}Click here: "${RESET}""${BLUE}${BOLD}""https://console.cloud.google.com/dataplex/search?project=$DEVSHELL_PROJECT_ID&qSystems=DATAPLEX"""${RESET}"

echo "${CYAN}${BOLD}Click here: "${RESET}""${BLUE}${BOLD}""https://console.cloud.google.com/dataplex/process/create-task/data-quality?project=$DEVSHELL_PROJECT_ID"""${RESET}"

echo "${YELLOW}${BOLD}NOW${RESET}" "${WHITE}${BOLD}FOLLOW${RESET}" "${GREEN}${BOLD}VIDEO'S INSTRUCTIONS${RESET}"

#-----------------------------------------------------end----------------------------------------------------------#