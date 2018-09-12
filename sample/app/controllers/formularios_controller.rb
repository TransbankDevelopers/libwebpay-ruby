class FormulariosController < ApplicationController
  def por_get
   @codigo = params[:codigo];
   if @codigo
      case @codigo
         when "123"
            @usuario = {:nombre => "Cornelio", :apellido => "Del Rancho"};
         when "456"
            @usuario = {:nombre => "Juansulo", :apellido => "Clayton"};
         when "789"
            @usuario = {:nombre => "Eros", :apellido => "Ramazzotti"};
         else
            @usuario = false;
         end
   end
end

  def por_post
  end
end
