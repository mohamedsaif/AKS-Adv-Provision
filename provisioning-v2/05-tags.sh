# We will be using these tags to mark all of the deployments with project/environment pairs
# ONLY execute ONCE the creation and adding of values

# Some variables are referenced in the 02-variables.sh script

az tag create --name environment
az tag create --name project

az tag add-value \
    --name environment \
    --value dev

az tag add-value \
    --name environment \
    --value stg

az tag add-value \
    --name environment \
    --value qa

az tag add-value \
    --name environment \
    --value prod

az tag add-value \
    --name project \
    --value $PROJECT_CODE


# This is created at the level of the subscription. So we will append --tags 'key1=value1 key2=value2'
# Tagging can help in setting up policies, cost management and other scenarios. 

echo "Tags Creation Completed"