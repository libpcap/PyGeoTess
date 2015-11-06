#distutils: language = c++
#cython: embedsignature=True
"""
This module exposes Cython GeoTess functionality from the pxd file into Python.

The class definitions here are Python-visible, and are simply wrappers that 
forward the Python-exposed methods directly to their Cython-exposed C++
counterparts, which have been exposed in the imported pxd file.

This module is also responsible for converting between Python types and c++
types, which sometimes involves annoying tricks.  For simple numerical types,
this conversion can be done automatically in the calling signature of a "def"
method if types are declared.  Complex C++ class types, for example, can't be
in a Python-visable "def" method because Python objects can't be automatically
cast to C++ types.  For these cases, sneaky factory functions that can used
accept the complex types must do the work.  Unfortunately, this means that any
constructor or method that accepts complex c++ can't be "directly" exposed to
Python.

Using both a pxd and a pyx file is done, partly, so that we can keep the
exposed c++ GeoTess functionality together in one namespace using "cimport",
so that we can name the classes exposed to Python the same as those in the
GeoTess c++.  This is sometimes confusing in error messages, however.

GeoTess functionality is intentionally a one-to-one translation into Python so
that any modifications to the way models and grids are used can be developed
and tested in in pure Python modules.  This makes it easier to try different
Python approaches to working with the underlying GeoTess library.


## Current conversion conventions

* GeoTess unit vectors are returned as 3-tuples of doubles, but internally
  managed with array.array.  This is because array.arrays exposes its pointer
  easily, and tuples are immutable.  Seems appropriate.


## Current headaches

* Deleting or garbage-collecting objects is dangerous.  Some objects are
  managed by other objects, so deleting them manually can crash the interpreter.
  I'm not sure how to fix this yet.

"""
import os

from cpython cimport array
import array

from cython.operator cimport dereference as deref

from libcpp.string cimport string
from libcpp.vector cimport vector

cimport clibgeotess as clib
import geotess.exc as exc

cdef class GeoTessGrid:
    cdef clib.GeoTessGrid *thisptr

    def __cinit__(self):
        self.thisptr = new clib.GeoTessGrid()

    def __dealloc__(self):
        if self.thisptr != NULL:
            del self.thisptr

    def loadGrid(self, const string& inputFile):
        if os.path.exists(inputFile):
            self.thisptr.loadGrid(inputFile)
        else:
            raise exc.GeoTessFileError("File not found.")

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

    def getVertex(self, int vertex):
        # XXX: how to get an array from the double * getVertex returns
        return self.thisptr.getVertex(vertex)


cdef class GeoTessMetaData:
    cdef clib.GeoTessMetaData *thisptr

    def __cinit__(self):
        self.thisptr = new clib.GeoTessMetaData()

    def __dealloc__(self):
        if self.thisptr != NULL:
            del self.thisptr

    def setEarthShape(self, const string& earthShapeName):
        self.thisptr.setEarthShape(earthShapeName)

    def setDescription(self, const string& dscr):
        self.thisptr.setDescription(dscr)

    def setLayerNames(self, const string& lyrNms):
        self.thisptr.setLayerNames(lyrNms)

    def setLayerTessIds(self, vector[int]& layrTsIds):
        """
        layrTsIds is an iterable of integers.
        """
        # http://www.peterbeerli.com/classes/images/f/f7/Isc4304cpluspluscython.pdf
        self.thisptr.setLayerTessIds(layrTsIds)

    def setAttributes(self, const string& nms, const string& unts):
        self.thisptr.setAttributes(nms, unts)

    def setDataType(self, const string& dt):
        self.thisptr.setDataType(dt)

    def setModelSoftwareVersion(self, const string& swVersion):
        self.thisptr.setModelSoftwareVersion(swVersion)

    def setModelGenerationDate(self, const string& genDate):
        self.thisptr.setModelGenerationDate(genDate)

    def toString(self):
        return self.thisptr.toString()


cdef class EarthShape:
    """
    Parameters
    ----------
    earthShape : str
        SPHERE - Geocentric and geographic latitudes are identical and
            conversion between depth and radius assume the Earth is a sphere
            with constant radius of 6371 km.
        GRS80 - Conversion between geographic and geocentric latitudes, and
            between depth and radius are performed using the parameters of the
            GRS80 ellipsoid.
        GRS80_RCONST - Conversion between geographic and geocentric latitudes
            are performed using the parameters of the GRS80 ellipsoid.
            Conversions between depth and radius assume the Earth is a sphere
            with radius 6371.
        WGS84 - Conversion between geographic and geocentric latitudes, and
            between depth and radius are performed using the parameters of the
            WGS84 ellipsoid.
        WGS84_RCONST - Conversion between geographic and geocentric latitudes
            are performed using the parameters of the WGS84 ellipsoid.
            Conversions between depth and radius assume the Earth is a sphere
            with radius 6371.

    """
    cdef clib.EarthShape *thisptr

    def __cinit__(self, earthShape="WGS84", raw=False):
        # raw=True means "just give me the wrapper class, I don't want it to
        # initialize a c++ pointer".  This is useful when you'll be using the
        # "wrap" method to capture a pointer something else generated.
        if not raw:
            self.thisptr = new clib.EarthShape(earthShape)

    def __dealloc__(self):
        if self.thisptr != NULL:
            del self.thisptr

    def getLonDegrees(self, double[:] v):
        """
        Convert a 3-component unit vector to a longitude, in degrees.

        """
        # v is a 1D typed memoryview on an iterable.
        # thispt.getLonDegrees expects a pointer
        # do this by passing the address of the first element, following
        # http://stackoverflow.com/a/14585530/745557

        return self.thisptr.getLonDegrees(&v[0])

    def getLatDegrees(self, double[:] v):
        """
        Convert a 3-component unit vector to a latitude, in degrees.

        """
        # see above

        return self.thisptr.getLatDegrees(&v[0])

    def getVectorDegrees(self, double lat, double lon):
        """
        Convert geographic lat, lon into a geocentric unit vector. The
        x-component points toward lat,lon = 0, 0. The y-component points toward
        lat,lon = 0, 90. The z-component points toward north pole.

        """
        # thisptr.getVectorDegrees wants two doubles and a pointer to an array
        # that will be filled in c++. we must create a Python object here 
        # that can be returned, and whos memory can be managed by Python, that
        # can be filled in c++ by passing its pointer, following
        # http://docs.cython.org/src/tutorial/array.html#zero-overhead-unsafe-access-to-raw-c-pointer
        cdef array.array v = array.array('d', [0.0, 0.0, 0.0])
        self.thisptr.getVectorDegrees(lat, lon, &v.data.as_doubles[0])

        return tuple(v.tolist())

    @staticmethod
    cdef EarthShape wrap(clib.EarthShape *cptr):
        cdef EarthShape inst = EarthShape(raw=True)
        inst.thisptr = cptr
        return inst


cdef class GeoTessModel:
    """
    GeoTessModel accepts a GeoTessGrid and GeoTessMetaData instance.  These
    instances are _copied_ into the GeoTessModel. Be warned that changes to
    them are _not_ reflected in the original instances.  This is done to
    simplify the life cycle of the underlying C++ memory, because GeoTessModel
    wants to assumes ownership of the provided C++ objects, including
    destruction.

    """
    cdef clib.GeoTessModel *thisptr

    def __cinit__(self, GeoTessGrid grid=None, GeoTessMetaData metaData=None):
        # https://groups.google.com/forum/#!topic/cython-users/iNmemRwUyuU
        cdef clib.GeoTessGrid *gptr
        cdef clib.GeoTessMetaData *mdptr

        if grid is None and metaData is None:
            self.thisptr = new clib.GeoTessModel()
        else:
            if sum((grid is None, metaData is None)) == 1:
                raise ValueError("Must provide both grid and metaData")

            # copy the grid and metadata, so that GeoTessModel can truly control
            # the destruction of the grid and metadata it uses.
            gptr = new clib.GeoTessGrid(deref(grid.thisptr))
            mdptr = new clib.GeoTessMetaData(deref(metaData.thisptr))

            # https://groups.google.com/forum/#!topic/cython-users/6I2HMUTPT6o
            self.thisptr = new clib.GeoTessModel(gptr, mdptr)

    def __dealloc__(self):
        # XXX: doing "del model" still crashes Python.  Dunno why yet.
        if self.thisptr != NULL:
            del self.thisptr

    # https://groups.google.com/forum/#!topic/cython-users/6I2HMUTPT6o

    def loadModel(self, const string& inputFile, relGridFilePath=""):
        # https://groups.google.com/forum/#!topic/cython-users/4ecKM-p8dPA
        if os.path.exists(inputFile):
            self.thisptr.loadModel(inputFile, relGridFilePath)
        else:
            raise exc.GeoTessFileError("Model file not found.")

    def writeModel(self, const string& outputFile):
        self.thisptr.writeModel(outputFile)

    def toString(self):
        return self.thisptr.toString()

    def getEarthShape(self):
        return EarthShape.wrap(&self.thisptr.getEarthShape())
