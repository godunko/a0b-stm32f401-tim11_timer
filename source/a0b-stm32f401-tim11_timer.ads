--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

pragma Restrictions (No_Elaboration_Code);

private with A0B.Time;
with A0B.Types;

package A0B.STM32F401.TIM11_Timer
  with Preelaborate
is

   procedure Initialize
     (Timer_Peripheral_Frequency : A0B.Types.Unsigned_32);

private

   procedure Internal_Request_Tick;

   procedure Internal_Set_Next
     (Span    : A0B.Time.Time_Span;
      Success : out Boolean);

end A0B.STM32F401.TIM11_Timer;
