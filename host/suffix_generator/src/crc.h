// Copyright 2020-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef __crc_h__
#define __crc_h__

unsigned crc_init(void);
void crc_step(unsigned *crc, unsigned char byte);
unsigned crc_finish(unsigned crc);

#endif
