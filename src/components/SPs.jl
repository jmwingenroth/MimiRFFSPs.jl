
using Mimi, CSVFiles, DataFrames, Query

@defcomp SPs begin

    countries = Index()

    country_names = Parameter{String}(index=[countries]) # need the names of the countries from the dimension
    id = Parameter(default=1)

    # TODO double check units on gases, do we want any other gases or parameters?
    population      = Variable(index=[time, countries], unit="million")
    gdp             = Variable(index=[time, countries], unit="billion US\$2020/yr")

    co2_emissions   = Variable(index=[time], unit="GtC/yr")
    ch4_emissions   = Variable(index=[time], unit="MtCH4/yr")
    n2o_emissions   = Variable(index=[time], unit="MtN/yr")

    function init(p,v,d)

        # ----------------------------------------------------------------------
        # Checks

        # TODO - any checks to do here?

        # ----------------------------------------------------------------------
        # Load Socioeconomic Data as Needed
        #   population in billions of individuals
        #   GDP in billions of $2020 USD

        g_datasets[:socioeconomic] = load(joinpath(@__DIR__, "..", "..", "data", "socioeconomic", "socioeconomic_$(p.id).csv")) |> DataFrame

        # Check Countries - each country found in the model countries parameter
        # must exist in the SSP socioeconomics dataframe 

        missing_countries = []
        for country in p.country_names
            !(country in unique(g_datasets[:socioeconomic].country)) && push!(missing_countries, country)
        end
        !isempty(missing_countries) && error("All countries in countries parameter must be found in SPs component Socioeconomic Dataframe, the following were not found: $(missing_countries)")

        # ----------------------------------------------------------------------
        # Load Emissions Data as Needed
        #   carbon dioxide emissions in GtC
        #   nitrous oxide emissions in MtN
        #   methane emissions in MtCH4

        g_datasets[:emissions] = load(joinpath(@__DIR__, "..", "..", "data", "emissions", "emissions_$(p.id).csv")) |> DataFrame
   
    end

    function run_timestep(p,v,d,t)

        year_label = gettime(t)

        # check that we only run the component where we have data
        if !(year_label in unique(g_datasets[:socioeconomic].year))
            error("Cannot run SP component in year $(year_label), SP socioeconomic variables not available for this model and year.")
        end
        if !(year_label in unique(g_datasets[:emissions].year))
            error("Cannot run SP component in year $(year_label), SP emissions variables only available for this model and year.")
        end

        # ----------------------------------------------------------------------
        # Socioeconomic

        # filter the dataframe for values with the year matching timestep
        # t and only the SP countries found in the model countries list,
        # already checked that all model countries are in SP countries list
        subset = g_datasets[:socioeconomic] |>
            @filter(_.year == year_label && _.country in p.country_names) |>
            DataFrame

        # get the ordered indices of the SP countries within the parameter 
        # of the model countries, already checked that all model countries
        # are in SP countries list
        order = indexin(p.country_names, subset.country)

        v.population[t,:] = subset.pop[order]
        v.gdp[t,:] = subset.gdp[order]

        # ----------------------------------------------------------------------
        # Emissions

        subset = g_rcp_datasets[:emissions] |>
                    @filter(_.year == year_label) |>
                    DataFrame

        v.co2_emissions[t] = subset.co2[1]
        v.ch4_emissions[t] = subset.ch4[1]
        v.n2o_emissions[t] = subset.n2o[1]

    end
end
