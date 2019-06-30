# This file exemplifies the workflow from data input to optimization result generation
using CapacityExpansion
using Clp
## LOAD DATA ##
state="GER_1" # or "GER_18" or "CA_1" or "TX_1"
years=[2016] #2016 works for GER_1 and CA_1, GER_1 can also be used with 2006 to 2016 and, GER_18 is 2015 TX_1 is 2008
# laod ts-data
ts_input_data = load_timeseries_data_provided(state;T=24, years=years) #CEP
# load cep-data
cep_data = load_cep_data_provided(state)
## CLUSTERING ##
# run aggregation with kmeans
ts_clust_data = run_clust(ts_input_data;method="hierarchical",representation="centroid",n_init=1,n_clust=5) # default k-means make sure that n_init is high enough otherwise the results could be crap and drive you crazy

# run aggregation with kmeans and have periods segmented
ts_seg_data = run_clust(ts_input_data;method="kmeans",representation="centroid",n_init=100,n_clust=5, n_seg=4) # default k-means make sure that n_init is high enough otherwise the results could be crap and drive you crazy

## OPTIMIZATION EXAMPLES##
# select optimizer
optimizer=Clp.Optimizer

# tweak the CO2 level
co2_result = run_opt(ts_clust_data.clust_data,cep_data,optimizer;co2_limit=50) #generally values between 1250 and 10 are interesting

# Include a Slack-Variable
slack_result = run_opt(ts_clust_data.clust_data,cep_data,optimizer;lost_el_load_cost=1e6, lost_CO2_emission_cost=700)


# Include existing infrastructure at no COST
ex_result = run_opt(ts_clust_data.clust_data,cep_data,optimizer;existing_infrastructure=true)

# Intraday storage (just within each period, same storage level at beginning and end)
simplestor_result = run_opt(ts_clust_data.clust_data,cep_data,optimizer;storage="simple")

# Interday storage (within each period & between the periods)
seasonalstor_result = run_opt(ts_clust_data.clust_data,cep_data,optimizer;storage="seasonal")

# Transmission
transmission_result = run_opt(ts_clust_data.clust_data,cep_data,optimizer;transmission=true)

# Segmentation
seg_result = run_opt(ts_seg_data.clust_data,cep_data,optimizer)

# Desing with clusered data and operation with ts_full_data
# First solve the clustered case
design_result = run_opt(ts_clust_data.clust_data,cep_data,optimizer;co2_limit=50)

#capacity_factors
design_variables=get_cep_design_variables(design_result)

# Use the design variable results for the operational run
operation_result = run_opt(ts_input_data,cep_data,design_result.opt_config,design_variables,optimizer;lost_el_load_cost=1e6,lost_CO2_emission_cost=700)

# Change scaling parameters
# Changing the scaling parameters is useful if the data you use represents a much smaller or bigger energy system than the ones representing Germany and California provided in this package
# Determine the right scaling parameters by checking the "real" values of COST, CAP, GEN... (real-VAR) in a solution using your data. Select the scaling parameters to match the following:
#   0.01 ≤ VAR  ≤ 100,     real-VAR = scale[:VAR] ⋅ VAR
# ⇔ 0.01 ≤ real-VAR / scale[:VAR] ≤ 100
scale=Dict{Symbol,Int}(:COST => 1e9, :CAP => 1e3, :GEN => 1e3, :SLACK => 1e3, :INTRASTOR => 1e3, :INTERSTOR => 1e6, :FLOW => 1e3, :TRANS =>1e3, :LL => 1e6, :LE => 1e9)
co2_result = run_opt(ts_clust_data.best_results,cep_data,optimizer;scale=scale, co2_limit=50)
