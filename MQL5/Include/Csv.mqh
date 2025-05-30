#include <Generic\HashMap.mqh>

void read_csv(const string filename, CHashMap<string, string> *&data[])
{
    int filehandle = FileOpen(filename, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ",");
    if(filehandle == INVALID_HANDLE)
    {
        Print("Failed to open file: ", filename);
        return;
    }

    // Read headers
    string headers[];
    int headerCount = 0;

    while(!FileIsEnding(filehandle))
    {
        string value = FileReadString(filehandle);
        if(value == "") break;

        ArrayResize(headers, headerCount + 1);
        headers[headerCount] = value;
        headerCount++;

        if(FileIsLineEnding(filehandle)) break;
    }

    // Read data rows
    int rowCount = 0;

    while(!FileIsEnding(filehandle))
    {
        CHashMap<string, string> *rowMap = new CHashMap<string, string>();

        for(int col = 0; col < headerCount; col++)
        {
            string value = FileReadString(filehandle);
            rowMap.Add(headers[col], value);

            if(FileIsLineEnding(filehandle)) break;
        }

        ArrayResize(data, rowCount + 1);
        data[rowCount] = rowMap;
        rowCount++;
    }

    FileClose(filehandle);
    Print("CSV read successfully. Rows: ", rowCount, ", Columns: ", headerCount);
}


void delete_csv(CHashMap<string, string> *&data[])
{
    for(int i = 0; i < ArraySize(data); i++)
    {
        if(data[i] != NULL)
        {
            delete data[i];
            data[i] = NULL;
        }
    }

    ArrayResize(data, 0);  // Limpa o array
}