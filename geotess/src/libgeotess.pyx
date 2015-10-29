"""
This module exposes Cython GeoTess functionality from the pxd file into Python.

The class definitions here are Python-visible, and are simply wrappers that 
forward the Python-exposed methods directly to their Cython-exposed c++
counterparts, which have been exposed in the imported pxd file.

Using both a pxd and a pyx file is done, partly, so that we can keep the
exposed c++ GeoTess functionality together in one namespace using "cimport",
and we can name the classes exposed to Python the same as those in the
GeoTess c++.

"""
from libcpp.string cimport string

cimport clibgeotess as clib

cdef class GeoTessGrid:
    cdef clib.GeoTessGrid *thisptr

    def __cinit__(self):
        self.thisptr = new clib.GeoTessGrid()

    def __dealloc__(self):
        del self.thisptr

    def loadGrid(self, const string& inputFile):
        self.thisptr.loadGrid(inputFile)

    def writeGrid(self, const string& fileName):
        self.thisptr.writeGrid(fileName)

    def getNLevels(self):
        return self.thisptr.getNLevels()
 
    def getNTriangles(self):
        return self.thisptr.getNTriangles()

    def getNTessellations(self):
        return self.thisptr.getNTessellations()

    def toString(self):
        return self.thisptr.toString()


cdef class GeoTessModel:
    cdef clib.GeoTessModel *thisptr

    def __cinit__(self):
        self.thisptr = new clib.GeoTessModel()

    def __dealloc__(self):
        del self.thisptr

    def loadModel(self, const string& inputFile, const string& relGridFilePath):
        self.thisptr.loadModel(inputFile, relGridFilePath)

    def writeModel(self, const string& outputFile=""):
        # http://grokbase.com/t/gg/cython-users/128gqk22kb/default-arguments-when-wrapping-c
        # http://stackoverflow.com/questions/5081678/handling-default-parameters-in-cython
        # https://groups.google.com/forum/#!topic/cython-users/4ecKM-p8dPA
        self.thisptr.writeModel(outputFile)

    def toString(self):
        return self.thisptr.toString()
