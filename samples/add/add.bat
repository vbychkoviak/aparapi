java ^
 -Djava.library.path=../../com.amd.aparapi.jni/dist ^
 -Dcom.amd.aparapi.executionMode=%1 ^
 -Dcom.amd.aparapi.enableShowGeneratedOpenCL=true ^
 -classpath ../../com.amd.aparapi/dist/aparapi.jar;add.jar ^
 com.amd.aparapi.sample.add.Main

