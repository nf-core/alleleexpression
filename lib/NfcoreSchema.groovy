class NfcoreSchema {
    // Placeholder for paramsSummaryMap method
    static Map paramsSummaryMap(workflow, params) {
        return params
    }

    // Placeholder for paramsHelp method
    static String paramsHelp(workflow, params) {
        return "Alleleexpression pipeline parameters:\n" + params.collect { k,v -> "  --${k}=${v}" }.join('\n')
    }

    // Placeholder for validateParameters method
    static Boolean validateParameters(workflow, params, log) {
        return true
    }

    // Placeholder for summary method
    static String summary(workflow, params, log) {
        return "Alleleexpression pipeline completed successfully!"
    }
}
