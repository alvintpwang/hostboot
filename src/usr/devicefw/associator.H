/* IBM_PROLOG_BEGIN_TAG                                                   */
/* This is an automatically generated prolog.                             */
/*                                                                        */
/* $Source: src/usr/devicefw/associator.H $                               */
/*                                                                        */
/* OpenPOWER HostBoot Project                                             */
/*                                                                        */
/* COPYRIGHT International Business Machines Corp. 2011,2014              */
/*                                                                        */
/* Licensed under the Apache License, Version 2.0 (the "License");        */
/* you may not use this file except in compliance with the License.       */
/* You may obtain a copy of the License at                                */
/*                                                                        */
/*     http://www.apache.org/licenses/LICENSE-2.0                         */
/*                                                                        */
/* Unless required by applicable law or agreed to in writing, software    */
/* distributed under the License is distributed on an "AS IS" BASIS,      */
/* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or        */
/* implied. See the License for the specific language governing           */
/* permissions and limitations under the License.                         */
/*                                                                        */
/* IBM_PROLOG_END_TAG                                                     */
/** @file associator.H
 *  Define the internal routing mechanism (DriverAssociator) for the framework.
 */
#ifndef __DEVICEFW_ASSOCIATOR_H
#define __DEVICEFW_ASSOCIATOR_H

#include <devicefw/driverif.H>
#include <sys/sync.h>
#include <vector>

#include "assoccontain.H"

namespace DeviceFW
{
    /** @class Associator
     *  @brief Class which performs the routing.  
     *
     *  Acts as a map of {op, access method, target type} -> deviceOp_t.  
     *  
     *  This class is not implemented using a stl::map (or similar container)
     *  because space required to store the map, due to the number of pointers 
     *  required to iterate to 3 levels of depth, would be much larger than
     *  needed.
     *
     *  This class instead uses the AssociationContainer as a map on 16bit
     *  offsets to compact the storage requirements.  Since we expect the
     *  same driver function may be registered multiple times (for different
     *  op / access method / target types), the class only stores the function
     *  pointers once and keeps an index of the function pointer in multiple
     *  locations in the map.
     *
     *  The map is stored in the AssociationContainer as:
     *          iv_associations[AccessType][OpType][TargetType].
     */
    class Associator
    {
        public:
                /** @brief Default constructor for Associator. */
            Associator();

            /** @brief Destructor for Associator.
             *  Removes all existing routing registrations.
             */
            ~Associator();
            
                /** Register routing interface.  See deviceRegisterRoute. */
            errlHndl_t registerRoute(int64_t i_opType,
                                     int64_t i_accType,
                                     int64_t i_targetType, 
                                     deviceOp_t i_regRoute);
                
                /** Perform routing.  See deviceOp. */
            errlHndl_t performOp(OperationType i_opType,
                                 TARGETING::Target* i_target,
                                 void* io_buffer, size_t& io_buflen,
                                 int64_t i_accessType, va_list i_addr);

        private:
            /**
             * @brief Find an associated function for the given operation
             *
             * @param[in] i_opType  Enumeration specifying the operation type
             * @param[in] i_accessType  Enumeration specifying the access type
             * @param[in] i_devType  Enumeration specifying the target type
             *
             * @return NULL if none found, else a function pointer
             */
            deviceOp_t findDeviceRoute( OperationType i_opType,
                                        TARGETING::TYPE i_devType,
                                        int64_t i_accessType );

        private:
            typedef std::vector<deviceOp_t> opVector_t;
            
                /** Mutex to provide thread-safety. (could be rw-lock) */
            mutex_t                 iv_mutex;   
                /** Vector of deviceOp_t functions registered. */
            opVector_t              iv_operations;
                /** Compacted offset map. */
            AssociationContainer    iv_associations;
                /** Index in map of the first level of the associations. */
            size_t                  iv_routeMap;

    };
}

#endif
