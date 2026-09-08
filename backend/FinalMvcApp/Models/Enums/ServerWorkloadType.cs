namespace FinalMvcApp.Models.Enums;

public enum ServerWorkloadType
{
    ModelTraining = 1,
    Inference = 2,
    Rendering = 3,
    DevelopmentCompilation = 4,
    DataProcessing = 5,
    WebBackendHosting = 6,
    GeneralCompute = 7
}
