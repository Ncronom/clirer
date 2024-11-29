package unit

get_data_set :: proc() -> (input: [5]string) {
    input = [5]string{
        "C:/Users/name/apps/search.exe", 
        "-strict",
        "-prefix:_",
        "-suffix:_,*",
        "nomenclature"
    }
    return input
}
