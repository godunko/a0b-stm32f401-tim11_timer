--
--  Copyright (C) 2024, Vadim Godunko <vgodunko@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
--

pragma Restrictions (No_Elaboration_Code);

with A0B.ARMv7M.NVIC_Utilities;
with A0B.STM32F401.SVD.RCC; use A0B.STM32F401.SVD.RCC;
with A0B.STM32F401.SVD.TIM; use A0B.STM32F401.SVD.TIM;
with A0B.Timer.Internals;

package body A0B.STM32F401.TIM11_Timer is

   procedure TIM1_TRG_COM_TIM11_Handler
     with Export, Convention => C, External_Name => "TIM1_TRG_COM_TIM11_Handler";

   Prescaler_Divider : constant := 1_000_000;
   --  Divider to compute number of timer peripheral clock ticks in the
   --  1 microsecond interval. This value is selected to avoid overflow
   --  of 16-bit prescaler at maximum frequency (84 MHz).

   Span_Divider      : constant := 1_000;
   --  Divider to compute number of microsecond ticks in the given time
   --  span.

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Timer_Peripheral_Frequency : A0B.Types.Unsigned_32)
   is
      use type A0B.Types.Unsigned_32;

   begin
      RCC_Periph.APB2ENR.TIM11EN := True;

      declare
         Aux : CR1_Register_2 := TIM11_Periph.CR1;

      begin
         Aux.CEN  := False;  --  Counter disabled
         Aux.UDIS := False;  --  UEV enabled.
         Aux.URS  := True;
         --  Only counter overflow generates an UEV if enabled.
         Aux.ARPE := False;  --  TIMx_ARR register is not buffered
         --  Aux.CDK  := <>;

         TIM11_Periph.CR1 := Aux;
      end;

      TIM11_Periph.PSC.PSC :=
        A0B.Types.Unsigned_16 (Timer_Peripheral_Frequency / Prescaler_Divider);

      --  Enable update interrupt

      declare
         Aux : DIER_Register_3 := TIM11_Periph.DIER;

      begin
         Aux.CC1IE := False;  --  CC1 interrupt disabled
         Aux.UIE   := True;   --  Update interrupt enabled

         TIM11_Periph.DIER := Aux;
      end;

      A0B.ARMv7M.NVIC_Utilities.Clear_Pending
        (A0B.STM32F401.TIM1_TRG_COM_TIM11);
      A0B.ARMv7M.NVIC_Utilities.Enable_Interrupt
        (A0B.STM32F401.TIM1_TRG_COM_TIM11);

      --  Initialize A0B Timer.

      A0B.Timer.Internals.Initialize;
   end Initialize;

   ---------------------------
   -- Internal_Request_Tick --
   ---------------------------

   procedure Internal_Request_Tick is
   begin
      --  Request TC interrupt to execute callback/schedule timer.

      A0B.ARMv7M.NVIC_Utilities.Set_Pending
        (A0B.STM32F401.TIM1_TRG_COM_TIM11);
   end Internal_Request_Tick;

   -----------------------
   -- Internal_Set_Next --
   -----------------------

   procedure Internal_Set_Next
     (Span    : A0B.Time.Time_Span;
      Success : out Boolean)
   is
      use type A0B.Types.Unsigned_64;

      Required_Ticks : constant A0B.Types.Unsigned_64 :=
        A0B.Types.Unsigned_64
          (A0B.Types.Integer_64'Max (A0B.Time.To_Nanoseconds (Span), 0))
           / A0B.Types.Unsigned_64 (Span_Divider);
      Ticks          : constant A0B.Types.Unsigned_64 :=
        A0B.Types.Unsigned_64'Min
          (Required_Ticks, A0B.Types.Unsigned_64 (A0B.Types.Unsigned_16'Last));
      --  Limit number of ticks by counter's capacity.

   begin
      if Ticks = 0 then
         --  Delay interval is not distinguishable by the timer.

         Success := False;

         return;
      end if;

      TIM11_Periph.ARR.ARR := A0B.Types.Unsigned_16 (Ticks);
      TIM11_Periph.EGR.UG  := True;
      TIM11_Periph.CR1.CEN := True;
      Success              := True;
   end Internal_Set_Next;

   --------------------------------
   -- TIM1_TRG_COM_TIM11_Handler --
   --------------------------------

   procedure TIM1_TRG_COM_TIM11_Handler is
   begin
      --  Disable timer and clear interrupt status.

      TIM11_Periph.CR1.CEN  := False;
      TIM11_Periph.SR.UIF   := False;
      TIM11_Periph.SR.CC1IF := False;

      --  Process tick

      A0B.Timer.Internals.On_Tick;
   end TIM1_TRG_COM_TIM11_Handler;

end A0B.STM32F401.TIM11_Timer;
