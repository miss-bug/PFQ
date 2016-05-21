/***************************************************************
 *
 * (C) 2011-16 Nicola Bonelli <nicola@pfq.io>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 * The full GNU General Public License is included in this distribution in
 * the file called "COPYING".
 *
 ****************************************************************/

#include <engine/global.h>


struct global_data default_global =
{
	.capture_incoming	= 1,
	.capture_outgoing	= 0,
	.capt_slot_size		= 1514,
	.xmit_slot_size		= 1514,
	.xmit_batch_len		= 1,
	.capt_batch_len		= 1,
	.vl_untag		= 0,
	.skb_pool_size		= 1024,
	.tx_affinity		= {0},
	.tx_thread_nr		= 0,
	.tx_rate_control_eager  = 1
};


struct global_data * global;


struct global_data *
pfq_global_init(void)
{
	return &default_global;
}

