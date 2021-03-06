/* IBM_PROLOG_BEGIN_TAG                                                   */
/* This is an automatically generated prolog.                             */
/*                                                                        */
/* $Source: src/usr/initservice/istepdispatcher/sptask.C $                */
/*                                                                        */
/* OpenPOWER HostBoot Project                                             */
/*                                                                        */
/* COPYRIGHT International Business Machines Corp. 2012,2014              */
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
/**
 *  @file sptask.C
 *
 *  SP / SPless task  detached from IStep Dispatcher.
 *      Handles
 *
 */


/******************************************************************************/
// Includes
/******************************************************************************/
#include    <stdint.h>
#include    <stdio.h>
#include    <string.h>


#include    <sys/task.h>                    //  tid_t, task_create, etc
#include    <sys/time.h>                    //  nanosleep
#include    <sys/msg.h>                     //  message Q's
#include    <mbox/mbox_queues.H>            //  MSG_HB_MSG_BASE


#include    <trace/interface.H>             //  trace support
#include    <errl/errlentry.H>              //  errlHndl_t

#include    <initservice/initsvcudistep.H>  //  InitSvcUserDetailsIstep
#include    <initservice/taskargs.H>        // TASK_ENTRY_MACRO

#include    <targeting/common/util.H>       //

#include    "istepdispatcher.H"
#include    "splesscommon.H"
#include    "istep_mbox_msgs.H"


namespace   INITSERVICE
{

using   namespace   ERRORLOG;               // IStepNameUserDetails
using   namespace   SPLESS;                 // SingleStepMode
using   namespace   TARGETING;              //

/******************************************************************************/
// Globals/Constants
/******************************************************************************/
extern trace_desc_t *g_trac_initsvc;

/**
 * @const   SPLess PAUSE - These two constants are used in a nanosleep() call
 *          below to sleep between polls of the StatusReg.  Typically this will
 *          be about 10 ms - the actual value will be determined empirically.
 */
const   uint64_t    SINGLESTEP_PAUSE_S     =   0;
const   uint64_t    SINGLESTEP_PAUSE_NS    =   10000000;

/**
 * @brief  userConsoleComm
 *
 * Communicate with User Console on VPO or Simics.
 * Forwards commands to HostBoot (IStep Dispatcher) via a message Q.
 * Forwards status from HostBoot to VPO or Simics user console.
 *
 * Stop and wait for the user console to send the next IStep to run.
 * Run that, then  wait for the next one.
 *
 * @param[in,out]  -   pointer to a message Q, passed in by the parent
 *
 * @return none
 */
void    userConsoleComm( void *  io_msgQ )
{
    SPLessCmd               l_cmd;
    SPLessSts               l_sts;
    uint8_t                 l_seqnum        =   0;
    int                     l_sr_rc         =   0;
    msg_q_t                 l_SendMsgQ      =   static_cast<msg_q_t>( io_msgQ );
    msg_t                   *l_pMsg         =   msg_allocate();
    msg_q_t                 l_RecvMsgQ      =   msg_q_create();
    msg_t                   *l_pCurrentMsg  =  NULL;

    TRACFCOMP( g_trac_initsvc,
            "userConsoleComm entry, args=%p",
            io_msgQ  );

    // initialize command reg
    l_cmd.val64 =   0;
    writeCmd( l_cmd );

    //  init status reg, enable ready bit
    l_sts.val64 =   0;
    l_sts.hdr.readybit  =   true;
    writeSts( l_sts );

    TRACFCOMP( g_trac_initsvc,
            "userConsoleComm : readybit set." );

    //  set Current to our message on entry
    l_pCurrentMsg   =   l_pMsg;
    //
    //  Start the polling loop.
    //
    while( 1 )
    {
        //  read command register from user console
        readCmd( l_cmd );

        //  process any pending commands
        if ( l_cmd.hdr.gobit )
        {
            l_cmd.hdr.readbit = 1;
            writeCmd( l_cmd );

            // get the sequence number from caller
            l_seqnum    =   l_cmd.hdr.seqnum;

            //  clear status
            l_sts.val64 =   0;

            //  set running bit, fill in istep and substep
            l_sts.hdr.runningbit    =   true;
            l_sts.hdr.readybit      =   true;

            // @todo modify hb-istep to check both running bit and seqnum
            // l_sts.hdr.seqnum        =   l_seqnum;
            l_sts.istep             =   l_cmd.istep;
            l_sts.substep           =   l_cmd.substep;


            // write the intermediate value back to the console.
            TRACDCOMP( g_trac_initsvc,
                    "userConsoleComm Write status (running) 0x%x.%x",
                    static_cast<uint32_t>( l_sts.val64 >> 32 ),
                    static_cast<uint32_t>( l_sts.val64 & 0x0ffffffff ) );

            writeSts( l_sts );

            // pass the command on to IstepDisp, block until reply

            l_pCurrentMsg->type     = ISTEP_MSG_TYPE;
            l_pCurrentMsg->data[0]  =
                ( ( static_cast<uint64_t>(l_cmd.istep & 0xFF) << 32) |
                  ( static_cast<uint64_t>(l_cmd.substep & 0xFF ) ) );
            l_pCurrentMsg->data[1]     =   0;
            l_pCurrentMsg->extra_data  =   NULL;

            TRACDCOMP( g_trac_initsvc,
            "userConsoleComm: sendmsg type=0x%08x, d0=0x%16x, d1=0x%16x, x=%p",
                       l_pCurrentMsg->type,
                       l_pCurrentMsg->data[0],
                       l_pCurrentMsg->data[1],
                       l_pCurrentMsg->extra_data );
            //
            //  msg_sendrecv_noblk  effectively splits the "channel" into
            //  a send Q and a receive Q
            //
            l_sr_rc =   msg_sendrecv_noblk( l_SendMsgQ, l_pCurrentMsg, l_RecvMsgQ );
            //  should never happen.
            assert( l_sr_rc == 0 );

            //  This should unblock on any message sent on the Q,
            l_pCurrentMsg  =   msg_wait( l_RecvMsgQ );

            // build status to return to console
            l_sts.istep         =   l_cmd.istep;
            l_sts.substep       =   l_cmd.substep;
            l_sts.hdr.status    =   0;

            // Clear command reg when the command is done
            TRACDCOMP( g_trac_initsvc,
                    "userConsoleComm Clear Command reg" );
            l_cmd.val64 =   0;
            writeCmd( l_cmd );


            TRACDCOMP( g_trac_initsvc,
            "userConsoleComm: rcvmsg type=0x%08x, d0=0x%16x, d1=0x%16x, x=%p",
                       l_pCurrentMsg->type,
                       l_pCurrentMsg->data[0],
                       l_pCurrentMsg->data[1],
                       l_pCurrentMsg->extra_data );

            if ( l_pCurrentMsg->type   == BREAKPOINT )
            {
                l_sts.hdr.status    =   SPLESS_AT_BREAK_POINT;
            }

            //  istep status is the hi word in the returned data 0
            //  this should be either 0 or a plid from a returned errorlog
            l_sts.istepStatus   =
                        static_cast<uint32_t>( l_pCurrentMsg->data[0] >> 32 );

            // finish filling in status
            l_sts.hdr.runningbit    =   false;
            l_sts.hdr.seqnum        =   l_seqnum;

            TRACDCOMP( g_trac_initsvc,
                    "userConsoleComm Write (finished) status 0x%x.%x",
                    static_cast<uint32_t>( l_sts.val64 >> 32 ),
                    static_cast<uint32_t>( l_sts.val64 & 0x0ffffffff ) );
            writeSts( l_sts );

            // clear command reg, including go bit (i.e. set to false)
            //  2012-04-27 hb-istep will clear the command reg after it sees
            //      the running bit turn on.
            //      Please save the following in case we have to turn this
            //      back on.

        }   //  endif   gobit

        // sleep, and wait for user to give us something else to do.
        if( TARGETING::is_vpo() )
        {
            // In VPO/VBU, yield the task, any real delay takes too long
            task_yield();
        }
        else
        {
            nanosleep( SINGLESTEP_PAUSE_S, SINGLESTEP_PAUSE_NS );
        }
    }   //  endwhile

    TRACFCOMP( g_trac_initsvc,
               "sptask: Uh-oh, we just exited...  what went wrong?" );

    //  @note
    //  Fell out of loop, clear sts reg and turn off readybit
    //  disable the ready bit so the user knows.
    l_sts.val64 =   0;
    l_sts.hdr.status    =   SPLESS_TASKRC_TERMINATED;
    l_sts.hdr.seqnum    =   l_seqnum;
    writeSts( l_sts );

    TRACFCOMP( g_trac_initsvc,
            "userConsoleComm exit" );

    //  free the message struct
    msg_free( l_pMsg  );

    // return to main to end task
}

void* spTask( void    *io_pArgs )
{

    TRACFCOMP( g_trac_initsvc,
            "spTask entry, args=%p",
            io_pArgs  );

    //  IStepDisp should not expect us to come back.
    task_detach();

    //  Start talking to VPO / Simics User console.
    userConsoleComm( io_pArgs );

    TRACFCOMP( g_trac_initsvc,
            "spTask exit." );

    // End the task.
    return NULL;
}


} // namespace
